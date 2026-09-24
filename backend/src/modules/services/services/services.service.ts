import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  ServiceListing,
  ServiceStatus,
  ServiceCategory,
  ServiceVerificationStatus,
} from '../entities/service-listing.entity.js';
import { ServiceFavorite } from '../entities/service-favorite.entity.js';
import {
  ServiceReport,
  ServiceReportStatus,
} from '../entities/service-report.entity.js';
import { User } from '../../users/entities/user.entity.js';
import { RedisService } from '../../../database/redis.service.js';
import { getLocalityCentroid } from '../../localities/utils/locality-centroid.util.js';
import { formatPrivacySafeDistance } from '../../nearby/dto/nearby-post-response.dto.js';
import { CreateServiceDto } from '../dto/create-service.dto.js';
import { UpdateServiceDto } from '../dto/update-service.dto.js';
import {
  GetServicesQueryDto,
  ServiceSortBy,
} from '../dto/get-services-query.dto.js';
import { CreateServiceReportDto } from '../dto/create-service-report.dto.js';
import {
  ServiceResponseDto,
  PaginatedServicesResponseDto,
} from '../dto/service-response.dto.js';

interface RawServiceRow {
  id: string;
  ownerId: string;
  title: string;
  description: string;
  category: ServiceCategory;
  status: ServiceStatus;
  verificationStatus: ServiceVerificationStatus;
  countryCode: string;
  state: string | null;
  district: string | null;
  city: string | null;
  locality: string | null;
  neighborhood: string | null;
  serviceRadiusKm: number;
  contactPhone: string | null;
  contactEmail: string | null;
  experienceYears: number | null;
  availability: string | null;
  startingPrice: string | number | null;
  currency: string;
  favoriteCount: string | number;
  createdAt: Date | string;
  updatedAt: Date | string;
  owner_id: string;
  owner_displayName: string | null;
  owner_avatarUrl: string | null;
  owner_locality: string | null;
  owner_city: string | null;
  currentUserFavorited: boolean | string | number;
  distance_meters?: number | string | null;
}

@Injectable()
export class ServicesService {
  private readonly logger = new Logger(ServicesService.name);
  private readonly maxCreatePerHour = 20;
  private readonly maxReportsPerHour = 10;
  private readonly maxSearchesPerMinute = 60;

  constructor(
    @InjectRepository(ServiceListing)
    private readonly serviceRepository: Repository<ServiceListing>,
    @InjectRepository(ServiceFavorite)
    private readonly favoriteRepository: Repository<ServiceFavorite>,
    @InjectRepository(ServiceReport)
    private readonly reportRepository: Repository<ServiceReport>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly redisService: RedisService,
  ) {}

  /**
   * Create a new local service listing with centroid resolution.
   */
  async createService(
    userId: string,
    dto: CreateServiceDto,
  ): Promise<ServiceResponseDto> {
    await this.checkRateLimit(
      `rate:service:create:${userId}`,
      this.maxCreatePerHour,
      3600,
      'Too many service listings created. Please wait before creating another service listing.',
    );

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User profile not found.');
    }

    const locality = dto.locality?.trim() || user.locality || null;
    const city = dto.city?.trim() || user.city || null;

    let lng: number;
    let lat: number;
    if (dto.latitude !== undefined && dto.longitude !== undefined) {
      lat = dto.latitude;
      lng = dto.longitude;
    } else {
      const coords = getLocalityCentroid(locality, city);
      lng = coords.longitude;
      lat = coords.latitude;
    }

    const service = this.serviceRepository.create({
      ownerId: userId,
      title: dto.title.trim(),
      description: dto.description.trim(),
      category: dto.category,
      status: ServiceStatus.ACTIVE,
      verificationStatus: ServiceVerificationStatus.UNVERIFIED,
      countryCode: dto.countryCode?.trim() || user.countryCode || 'IN',
      state: dto.state?.trim() || user.state || null,
      district: dto.district?.trim() || user.district || null,
      city,
      locality,
      neighborhood: dto.neighborhood?.trim() || user.neighborhood || null,
      serviceRadiusKm: dto.serviceRadiusKm ?? 10,
      contactPhone: dto.contactPhone?.trim() || null,
      contactEmail: dto.contactEmail?.trim() || null,
      experienceYears: dto.experienceYears ?? null,
      availability: dto.availability?.trim() || null,
      startingPrice: dto.startingPrice ?? null,
      currency: 'INR',
      favoriteCount: 0,
    });

    const saved = await this.serviceRepository.save(service);

    // Update PostGIS geometry location point safely
    await this.serviceRepository.query(
      `UPDATE "service_listings"
       SET "location" = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
       WHERE "id" = $3`,
      [lng, lat, saved.id],
    );

    return this.mapToServiceResponse(saved, user, false, true);
  }

  /**
   * Discover and search local services with filters, PostGIS radius, and cursor pagination.
   */
  async getServices(
    userId: string,
    query: GetServicesQueryDto,
  ): Promise<PaginatedServicesResponseDto> {
    await this.checkRateLimit(
      `rate:service:search:${userId}`,
      this.maxSearchesPerMinute,
      60,
      'Too many search requests. Please wait a moment.',
    );

    const limit = Math.min(query.limit || 20, 50);
    const hasSpatialCoords =
      query.latitude !== undefined && query.longitude !== undefined;
    const radiusMeters = query.radius ? query.radius * 1000 : null;

    const qb = this.serviceRepository
      .createQueryBuilder('service')
      .leftJoin('users', 'owner', 'owner.id = service.ownerId')
      .leftJoin(
        'service_favorites',
        'fav',
        'fav.serviceId = service.id AND fav.userId = :userId',
        { userId },
      )
      .select([
        'service.id AS id',
        'service.ownerId AS "ownerId"',
        'service.title AS title',
        'service.description AS description',
        'service.category AS category',
        'service.status AS status',
        'service.verificationStatus AS "verificationStatus"',
        'service.countryCode AS "countryCode"',
        'service.state AS state',
        'service.district AS district',
        'service.city AS city',
        'service.locality AS locality',
        'service.neighborhood AS neighborhood',
        'service.serviceRadiusKm AS "serviceRadiusKm"',
        'service.contactPhone AS "contactPhone"',
        'service.contactEmail AS "contactEmail"',
        'service.experienceYears AS "experienceYears"',
        'service.availability AS availability',
        'service.startingPrice AS "startingPrice"',
        'service.currency AS currency',
        'service.favoriteCount AS "favoriteCount"',
        'service.createdAt AS "createdAt"',
        'service.updatedAt AS "updatedAt"',
        'owner.id AS owner_id',
        'owner.displayName AS "owner_displayName"',
        'owner.avatarUrl AS "owner_avatarUrl"',
        'owner.locality AS "owner_locality"',
        'owner.city AS "owner_city"',
        'CASE WHEN fav.id IS NOT NULL THEN true ELSE false END AS "currentUserFavorited"',
      ])
      .where('service.deletedAt IS NULL');

    // Filter by status (default to active for public discovery)
    if (query.status) {
      qb.andWhere('service.status = :status', { status: query.status });
    } else {
      qb.andWhere('service.status = :status', {
        status: ServiceStatus.ACTIVE,
      });
    }

    // Keyword search over title, description, and category
    if (query.query && query.query.trim()) {
      const term = `%${query.query.trim()}%`;
      qb.andWhere(
        '(service.title ILIKE :term OR service.description ILIKE :term OR service.category::text ILIKE :term)',
        { term },
      );
    }

    // Category filter
    if (query.category) {
      qb.andWhere('service.category = :category', { category: query.category });
    }

    // Locality and City text filters
    if (query.locality && query.locality.trim()) {
      qb.andWhere('service.locality ILIKE :locality', {
        locality: `%${query.locality.trim()}%`,
      });
    }
    if (query.city && query.city.trim()) {
      qb.andWhere('service.city ILIKE :city', {
        city: `%${query.city.trim()}%`,
      });
    }

    // PostGIS Spatial filtering and distance selection
    if (hasSpatialCoords) {
      qb.addSelect(
        'ROUND(ST_Distance(service.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) AS distance_meters',
      );
      qb.setParameters({
        lng: query.longitude,
        lat: query.latitude,
      });

      if (radiusMeters) {
        qb.andWhere('service.location IS NOT NULL');
        qb.andWhere(
          'ST_DWithin(service.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :radiusMeters)',
          { radiusMeters },
        );
      }
    }

    // Cursor Pagination & Sorting
    const sortBy = query.sortBy || ServiceSortBy.NEWEST;
    if (query.cursor) {
      this.applyCursorFilter(qb, query.cursor, sortBy, hasSpatialCoords);
    }

    // Deterministic ordering
    if (sortBy === ServiceSortBy.NEAREST && hasSpatialCoords) {
      qb.orderBy('distance_meters', 'ASC')
        .addOrderBy('service.createdAt', 'DESC')
        .addOrderBy('service.id', 'DESC');
    } else {
      qb.orderBy('service.createdAt', 'DESC').addOrderBy('service.id', 'DESC');
    }

    qb.limit(limit + 1);

    const rawRows: RawServiceRow[] = await qb.getRawMany();
    const hasMore = rawRows.length > limit;
    const rows = hasMore ? rawRows.slice(0, limit) : rawRows;

    // Next cursor
    let nextCursor: string | null = null;
    if (hasMore && rows.length > 0) {
      const last = rows[rows.length - 1];
      nextCursor = this.generateNextCursor(last, sortBy, hasSpatialCoords);
    }

    const items: ServiceResponseDto[] = rows.map((r) => {
      const isFavorited =
        r.currentUserFavorited === true ||
        r.currentUserFavorited === 'true' ||
        r.currentUserFavorited === 1;

      let distanceText: string | null = null;
      let distanceMetersRounded: number | null = null;
      if (r.distance_meters !== undefined && r.distance_meters !== null) {
        const m = Math.round(parseFloat(r.distance_meters.toString()));
        const formatted = formatPrivacySafeDistance(m);
        distanceText = formatted.distanceText;
        distanceMetersRounded = formatted.distanceMetersRounded;
      }

      return {
        id: r.id,
        ownerId: r.ownerId,
        owner: {
          id: r.owner_id ?? r.ownerId,
          displayName: r.owner_displayName ?? 'Service Provider',
          avatarUrl: r.owner_avatarUrl ?? null,
          locality: r.owner_locality ?? r.locality ?? null,
          city: r.owner_city ?? r.city ?? null,
        },
        title: r.title,
        description: r.description,
        category: r.category,
        status: r.status,
        verificationStatus: r.verificationStatus,
        countryCode: r.countryCode ?? 'IN',
        state: r.state ?? null,
        district: r.district ?? null,
        city: r.city ?? null,
        locality: r.locality ?? null,
        neighborhood: r.neighborhood ?? null,
        serviceRadiusKm: r.serviceRadiusKm ?? 10,
        contactPhone: r.contactPhone ?? null,
        contactEmail: r.contactEmail ?? null,
        experienceYears: r.experienceYears !== null ? parseInt(r.experienceYears.toString(), 10) : null,
        availability: r.availability ?? null,
        startingPrice: r.startingPrice !== null ? parseFloat(r.startingPrice.toString()) : null,
        currency: r.currency ?? 'INR',
        favoriteCount: parseInt(r.favoriteCount.toString(), 10) || 0,
        isFavorited,
        isOwner: r.ownerId === userId,
        distance: distanceText,
        distanceMeters: distanceMetersRounded,
        createdAt: new Date(r.createdAt),
        updatedAt: new Date(r.updatedAt),
      };
    });

    return {
      items,
      nextCursor,
      hasMore,
    };
  }

  /**
   * Get single service detail with provider summary and favorite state.
   */
  async getServiceById(
    id: string,
    userId: string,
  ): Promise<ServiceResponseDto> {
    const service = await this.serviceRepository.findOne({
      where: { id },
      relations: ['owner'],
    });

    if (!service || service.deletedAt) {
      throw new NotFoundException('Service listing not found.');
    }

    if (service.status !== ServiceStatus.ACTIVE && service.ownerId !== userId) {
      throw new NotFoundException('Service listing not found or is currently inactive.');
    }

    const favorite = await this.favoriteRepository.findOne({
      where: { serviceId: id, userId },
    });

    return this.mapToServiceResponse(
      service,
      service.owner,
      !!favorite,
      service.ownerId === userId,
    );
  }

  /**
   * Update service listing (Owner only).
   */
  async updateService(
    id: string,
    userId: string,
    dto: UpdateServiceDto,
  ): Promise<ServiceResponseDto> {
    const service = await this.serviceRepository.findOne({
      where: { id },
      relations: ['owner'],
    });

    if (!service || service.deletedAt) {
      throw new NotFoundException('Service listing not found.');
    }

    if (service.ownerId !== userId) {
      throw new ForbiddenException('You are not authorized to update this service listing.');
    }

    if (dto.title !== undefined) service.title = dto.title.trim();
    if (dto.category !== undefined) service.category = dto.category;
    if (dto.description !== undefined) service.description = dto.description.trim();
    if (dto.locality !== undefined) service.locality = dto.locality?.trim() || null;
    if (dto.city !== undefined) service.city = dto.city?.trim() || null;
    if (dto.state !== undefined) service.state = dto.state?.trim() || null;
    if (dto.district !== undefined) service.district = dto.district?.trim() || null;
    if (dto.neighborhood !== undefined) service.neighborhood = dto.neighborhood?.trim() || null;
    if (dto.serviceRadiusKm !== undefined) service.serviceRadiusKm = dto.serviceRadiusKm;
    if (dto.contactPhone !== undefined) service.contactPhone = dto.contactPhone?.trim() || null;
    if (dto.contactEmail !== undefined) service.contactEmail = dto.contactEmail?.trim() || null;
    if (dto.experienceYears !== undefined) service.experienceYears = dto.experienceYears ?? null;
    if (dto.availability !== undefined) service.availability = dto.availability?.trim() || null;
    if (dto.startingPrice !== undefined) service.startingPrice = dto.startingPrice ?? null;

    const updated = await this.serviceRepository.save(service);

    if (dto.latitude !== undefined && dto.longitude !== undefined) {
      await this.serviceRepository.query(
        `UPDATE "service_listings"
         SET "location" = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
         WHERE "id" = $3`,
        [dto.longitude, dto.latitude, id],
      );
    }

    const favorite = await this.favoriteRepository.findOne({
      where: { serviceId: id, userId },
    });

    return this.mapToServiceResponse(updated, service.owner, !!favorite, true);
  }

  /**
   * Update lifecycle status of service (Owner only).
   */
  async updateServiceStatus(
    id: string,
    userId: string,
    status: ServiceStatus,
  ): Promise<ServiceResponseDto> {
    const service = await this.serviceRepository.findOne({
      where: { id },
      relations: ['owner'],
    });

    if (!service || service.deletedAt) {
      throw new NotFoundException('Service listing not found.');
    }

    if (service.ownerId !== userId) {
      throw new ForbiddenException('You are not authorized to modify the status of this service listing.');
    }

    service.status = status;
    const updated = await this.serviceRepository.save(service);

    return this.mapToServiceResponse(updated, service.owner, false, true);
  }

  /**
   * Soft delete service listing (Owner only).
   */
  async deleteService(
    id: string,
    userId: string,
  ): Promise<{ success: boolean; message: string }> {
    const service = await this.serviceRepository.findOne({
      where: { id },
    });

    if (!service || service.deletedAt) {
      throw new NotFoundException('Service listing not found.');
    }

    if (service.ownerId !== userId) {
      throw new ForbiddenException('You are not authorized to delete this service listing.');
    }

    await this.serviceRepository.softDelete({ id });
    return { success: true, message: 'Service listing deleted successfully.' };
  }

  /**
   * Get current user's services with cursor pagination.
   */
  async getMyServices(
    userId: string,
    status?: ServiceStatus,
    cursor?: string,
    limit: number = 20,
  ): Promise<PaginatedServicesResponseDto> {
    const safeLimit = Math.min(limit, 50);

    const qb = this.serviceRepository
      .createQueryBuilder('service')
      .leftJoinAndSelect('service.owner', 'owner')
      .where('service.ownerId = :userId', { userId })
      .andWhere('service.deletedAt IS NULL');

    if (status) {
      qb.andWhere('service.status = :status', { status });
    }

    if (cursor) {
      const decoded = Buffer.from(cursor, 'base64').toString('utf8');
      const [cursorCreatedAt, cursorId] = decoded.split(':::');
      if (cursorCreatedAt && cursorId) {
        qb.andWhere(
          '(service.createdAt < :cursorCreatedAt OR (service.createdAt = :cursorCreatedAt AND service.id < :cursorId))',
          { cursorCreatedAt: new Date(cursorCreatedAt), cursorId },
        );
      }
    }

    qb.orderBy('service.createdAt', 'DESC')
      .addOrderBy('service.id', 'DESC')
      .limit(safeLimit + 1);

    const services = await qb.getMany();
    const hasMore = services.length > safeLimit;
    const items = hasMore ? services.slice(0, safeLimit) : services;

    let nextCursor: string | null = null;
    if (hasMore && items.length > 0) {
      const last = items[items.length - 1];
      nextCursor = Buffer.from(
        `${last.createdAt.toISOString()}:::${last.id}`,
      ).toString('base64');
    }

    return {
      items: items.map((s) =>
        this.mapToServiceResponse(s, s.owner, false, true),
      ),
      nextCursor,
      hasMore,
    };
  }

  /**
   * Toggle favorite state for a service.
   */
  async toggleFavorite(
    id: string,
    userId: string,
    favorite: boolean,
  ): Promise<{ isFavorited: boolean; favoriteCount: number }> {
    const service = await this.serviceRepository.findOne({
      where: { id },
    });

    if (!service || service.deletedAt) {
      throw new NotFoundException('Service listing not found.');
    }

    const existing = await this.favoriteRepository.findOne({
      where: { serviceId: id, userId },
    });

    if (favorite) {
      if (!existing) {
        const fav = this.favoriteRepository.create({
          serviceId: id,
          userId,
        });
        await this.favoriteRepository.save(fav);
        await this.serviceRepository.increment({ id }, 'favoriteCount', 1);
        service.favoriteCount += 1;
      }
    } else {
      if (existing) {
        await this.favoriteRepository.delete({ id: existing.id });
        if (service.favoriteCount > 0) {
          await this.serviceRepository.decrement({ id }, 'favoriteCount', 1);
          service.favoriteCount -= 1;
        }
      }
    }

    return {
      isFavorited: favorite,
      favoriteCount: Math.max(0, service.favoriteCount),
    };
  }

  /**
   * Report a service listing for moderation review.
   */
  async reportService(
    id: string,
    reporterId: string,
    dto: CreateServiceReportDto,
  ): Promise<{ success: boolean; message: string }> {
    await this.checkRateLimit(
      `rate:service:report:${reporterId}`,
      this.maxReportsPerHour,
      3600,
      'Too many reports submitted. Please wait before submitting another report.',
    );

    const service = await this.serviceRepository.findOne({
      where: { id },
    });

    if (!service || service.deletedAt) {
      throw new NotFoundException('Service listing not found.');
    }

    if (service.ownerId === reporterId) {
      throw new BadRequestException('You cannot report your own service listing.');
    }

    const existingReport = await this.reportRepository.findOne({
      where: { serviceId: id, reporterId },
    });

    if (existingReport) {
      throw new ConflictException('You have already submitted a report for this service.');
    }

    const report = this.reportRepository.create({
      serviceId: id,
      reporterId,
      reason: dto.reason,
      details: dto.details?.trim() || null,
      status: ServiceReportStatus.PENDING,
    });

    await this.reportRepository.save(report);
    return {
      success: true,
      message: 'Report submitted successfully. Our local community moderators will review it.',
    };
  }

  /**
   * List all centralized service categories.
   */
  getCategories(): Array<{ id: ServiceCategory; label: string; description: string }> {
    return [
      { id: ServiceCategory.HOME_REPAIR, label: 'Home Repair & Plumbing', description: 'Electricians, plumbers, carpenters, appliance repair' },
      { id: ServiceCategory.EDUCATION, label: 'Tutors & Lessons', description: 'Home tutors, music teachers, academic coaching' },
      { id: ServiceCategory.BEAUTY, label: 'Beauty & Grooming', description: 'At-home salons, makeup artists, stylists' },
      { id: ServiceCategory.CLEANING, label: 'Cleaning & Housekeeping', description: 'Deep cleaning, pest control, housekeeping' },
      { id: ServiceCategory.PHOTOGRAPHY, label: 'Photography & Videography', description: 'Event photographers, shoot videographers' },
      { id: ServiceCategory.AUTOMOTIVE, label: 'Automotive Services', description: 'Doorstep car wash, mechanic, roadside assistance' },
      { id: ServiceCategory.TECHNOLOGY, label: 'Tech & Device Repair', description: 'Laptop, PC, mobile repair, WiFi setup' },
      { id: ServiceCategory.PERSONAL_SERVICES, label: 'Personal & Care Services', description: 'Elderly care, pet sitters, fitness trainers' },
      { id: ServiceCategory.OTHER, label: 'Other Local Services', description: 'General neighborhood services' },
    ];
  }

  private mapToServiceResponse(
    s: ServiceListing,
    owner: User,
    isFavorited: boolean,
    isOwner: boolean,
  ): ServiceResponseDto {
    return {
      id: s.id,
      ownerId: s.ownerId,
      owner: {
        id: owner?.id ?? s.ownerId,
        displayName: owner?.displayName ?? 'Neighbor',
        avatarUrl: owner?.avatarUrl ?? null,
        locality: owner?.locality ?? s.locality ?? null,
        city: owner?.city ?? s.city ?? null,
      },
      title: s.title,
      description: s.description,
      category: s.category,
      status: s.status,
      verificationStatus: s.verificationStatus,
      countryCode: s.countryCode ?? 'IN',
      state: s.state ?? null,
      district: s.district ?? null,
      city: s.city ?? null,
      locality: s.locality ?? null,
      neighborhood: s.neighborhood ?? null,
      serviceRadiusKm: s.serviceRadiusKm ?? 10,
      contactPhone: s.contactPhone ?? null,
      contactEmail: s.contactEmail ?? null,
      experienceYears:
        s.experienceYears != null
          ? parseInt(s.experienceYears.toString(), 10)
          : null,
      availability: s.availability ?? null,
      startingPrice:
        s.startingPrice != null
          ? parseFloat(s.startingPrice.toString())
          : null,
      currency: s.currency ?? 'INR',
      favoriteCount: s.favoriteCount ?? 0,
      isFavorited,
      isOwner,
      distance: null,
      distanceMeters: null,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    };
  }

  private applyCursorFilter(
    qb: any,
    cursor: string,
    sortBy: ServiceSortBy,
    hasSpatialCoords: boolean,
  ): void {
    try {
      const decoded = Buffer.from(cursor, 'base64').toString('utf8');
      const parts = decoded.split(':::');

      if (sortBy === ServiceSortBy.NEAREST && hasSpatialCoords && parts.length === 3) {
        const [dist, createdAt, id] = parts;
        qb.andWhere(
          `(ROUND(ST_Distance(service.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) > :dist
           OR (ROUND(ST_Distance(service.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) = :dist AND service.createdAt < :createdAt)
           OR (ROUND(ST_Distance(service.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) = :dist AND service.createdAt = :createdAt AND service.id < :id))`,
          { dist: parseFloat(dist), createdAt: new Date(createdAt), id },
        );
      } else if (parts.length >= 2) {
        const [createdAt, id] = parts;
        qb.andWhere(
          '(service.createdAt < :createdAt OR (service.createdAt = :createdAt AND service.id < :id))',
          { createdAt: new Date(createdAt), id },
        );
      }
    } catch (e) {
      this.logger.warn(`Failed to parse pagination cursor: ${cursor}`, e);
    }
  }

  private generateNextCursor(
    row: RawServiceRow,
    sortBy: ServiceSortBy,
    hasSpatialCoords: boolean,
  ): string {
    const createdAtStr =
      row.createdAt instanceof Date
        ? row.createdAt.toISOString()
        : new Date(row.createdAt).toISOString();

    if (
      sortBy === ServiceSortBy.NEAREST &&
      hasSpatialCoords &&
      row.distance_meters !== undefined &&
      row.distance_meters !== null
    ) {
      return Buffer.from(
        `${row.distance_meters}:::${createdAtStr}:::${row.id}`,
      ).toString('base64');
    }

    return Buffer.from(`${createdAtStr}:::${row.id}`).toString('base64');
  }

  private async checkRateLimit(
    key: string,
    limit: number,
    windowSeconds: number,
    errorMessage: string,
  ): Promise<void> {
    try {
      const current = await this.redisService.incr(key);
      if (current === 1) {
        await this.redisService.expire(key, windowSeconds);
      }
      if (current > limit) {
        throw new HttpException(
          {
            statusCode: HttpStatus.TOO_MANY_REQUESTS,
            message: errorMessage,
            error: 'Too Many Requests',
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    } catch (err) {
      if (err instanceof HttpException) throw err;
      this.logger.warn(`Redis rate limit check skipped due to error: ${err}`);
    }
  }
}
