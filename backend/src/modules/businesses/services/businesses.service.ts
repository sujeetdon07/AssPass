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
  Business,
  BusinessStatus,
  BusinessCategory,
  BusinessVerificationStatus,
} from '../entities/business.entity.js';
import { BusinessImage } from '../entities/business-image.entity.js';
import { BusinessService } from '../entities/business-service.entity.js';
import { BusinessFavorite } from '../entities/business-favorite.entity.js';
import {
  BusinessReport,
  BusinessReportStatus,
} from '../entities/business-report.entity.js';
import { User } from '../../users/entities/user.entity.js';
import { RedisService } from '../../../database/redis.service.js';
import { getLocalityCentroid } from '../../localities/utils/locality-centroid.util.js';
import { formatPrivacySafeDistance } from '../../nearby/dto/nearby-post-response.dto.js';
import { CreateBusinessDto } from '../dto/create-business.dto.js';
import { UpdateBusinessDto } from '../dto/update-business.dto.js';
import {
  GetBusinessesQueryDto,
  BusinessSortBy,
} from '../dto/get-businesses-query.dto.js';
import { CreateBusinessReportDto } from '../dto/create-business-report.dto.js';
import {
  BusinessResponseDto,
  PaginatedBusinessesResponseDto,
} from '../dto/business-response.dto.js';
import { evaluateOperatingStatus } from '../utils/operating-hours.util.js';

interface RawBusinessRow {
  id: string;
  ownerId: string;
  name: string;
  slug: string;
  description: string;
  category: BusinessCategory;
  status: BusinessStatus;
  verificationStatus: BusinessVerificationStatus;
  countryCode: string;
  state: string | null;
  district: string | null;
  city: string | null;
  locality: string | null;
  neighborhood: string | null;
  address: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  website: string | null;
  timezone: string;
  operatingHours: any;
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
export class BusinessesService {
  private readonly logger = new Logger(BusinessesService.name);
  private readonly maxCreatePerHour = 20;
  private readonly maxReportsPerHour = 10;
  private readonly maxSearchesPerMinute = 60;

  constructor(
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(BusinessImage)
    private readonly imageRepository: Repository<BusinessImage>,
    @InjectRepository(BusinessService)
    private readonly businessServiceRepository: Repository<BusinessService>,
    @InjectRepository(BusinessFavorite)
    private readonly favoriteRepository: Repository<BusinessFavorite>,
    @InjectRepository(BusinessReport)
    private readonly reportRepository: Repository<BusinessReport>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly redisService: RedisService,
  ) {}

  /**
   * Helper to generate unique, safe slug for business
   */
  private generateSlug(name: string): string {
    const base = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '')
      .slice(0, 140);
    const suffix = Math.random().toString(36).substring(2, 8);
    return `${base}-${suffix}`;
  }

  /**
   * Create a new business listing with server-side validation and centroid resolution.
   */
  async createBusiness(
    userId: string,
    dto: CreateBusinessDto,
  ): Promise<BusinessResponseDto> {
    await this.checkRateLimit(
      `rate:business:create:${userId}`,
      this.maxCreatePerHour,
      3600,
      'Too many businesses created. Please wait before registering another business.',
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

    const slug = this.generateSlug(dto.name);

    const business = this.businessRepository.create({
      ownerId: userId,
      name: dto.name.trim(),
      slug,
      description: dto.description.trim(),
      category: dto.category,
      status: BusinessStatus.ACTIVE,
      verificationStatus: BusinessVerificationStatus.UNVERIFIED,
      countryCode: dto.countryCode?.trim() || user.countryCode || 'IN',
      state: dto.state?.trim() || user.state || null,
      district: dto.district?.trim() || user.district || null,
      city,
      locality,
      neighborhood: dto.neighborhood?.trim() || user.neighborhood || null,
      address: dto.address?.trim() || null,
      contactPhone: dto.contactPhone?.trim() || null,
      contactEmail: dto.contactEmail?.trim() || null,
      website: dto.website?.trim() || null,
      timezone: dto.timezone?.trim() || 'Asia/Kolkata',
      operatingHours: dto.operatingHours || null,
      favoriteCount: 0,
    });

    const savedBusiness = await this.businessRepository.save(business);

    // Update PostGIS geometry location point safely
    await this.businessRepository.query(
      `UPDATE "businesses"
       SET "location" = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
       WHERE "id" = $3`,
      [lng, lat, savedBusiness.id],
    );

    // Save images if provided
    let savedImages: BusinessImage[] = [];
    if (dto.images && dto.images.length > 0) {
      const imageEntities = dto.images.map((img, idx) =>
        this.imageRepository.create({
          businessId: savedBusiness.id,
          url: img.url.trim(),
          displayOrder: img.displayOrder ?? idx,
        }),
      );
      savedImages = await this.imageRepository.save(imageEntities);
    }

    // Save services if provided
    let savedServices: BusinessService[] = [];
    if (dto.services && dto.services.length > 0) {
      const serviceEntities = dto.services.map((svc) =>
        this.businessServiceRepository.create({
          businessId: savedBusiness.id,
          name: svc.name.trim(),
          description: svc.description?.trim() || null,
          startingPrice: svc.startingPrice ?? null,
          currency: 'INR',
        }),
      );
      savedServices = await this.businessServiceRepository.save(serviceEntities);
    }

    return this.mapToBusinessResponse(
      savedBusiness,
      user,
      false,
      true,
      savedImages,
      savedServices,
    );
  }

  /**
   * Discover and search businesses with filters, PostGIS radius, and cursor pagination.
   */
  async getBusinesses(
    userId: string,
    query: GetBusinessesQueryDto,
  ): Promise<PaginatedBusinessesResponseDto> {
    await this.checkRateLimit(
      `rate:business:search:${userId}`,
      this.maxSearchesPerMinute,
      60,
      'Too many search requests. Please wait a moment.',
    );

    const limit = Math.min(query.limit || 20, 50);
    const hasSpatialCoords =
      query.latitude !== undefined && query.longitude !== undefined;
    const radiusMeters = query.radius ? query.radius * 1000 : null;

    const qb = this.businessRepository
      .createQueryBuilder('business')
      .leftJoin('users', 'owner', 'owner.id = business.ownerId')
      .leftJoin(
        'business_favorites',
        'fav',
        'fav.businessId = business.id AND fav.userId = :userId',
        { userId },
      )
      .select([
        'business.id AS id',
        'business.ownerId AS "ownerId"',
        'business.name AS name',
        'business.slug AS slug',
        'business.description AS description',
        'business.category AS category',
        'business.status AS status',
        'business.verificationStatus AS "verificationStatus"',
        'business.countryCode AS "countryCode"',
        'business.state AS state',
        'business.district AS district',
        'business.city AS city',
        'business.locality AS locality',
        'business.neighborhood AS neighborhood',
        'business.address AS address',
        'business.contactPhone AS "contactPhone"',
        'business.contactEmail AS "contactEmail"',
        'business.website AS website',
        'business.timezone AS timezone',
        'business.operatingHours AS "operatingHours"',
        'business.favoriteCount AS "favoriteCount"',
        'business.createdAt AS "createdAt"',
        'business.updatedAt AS "updatedAt"',
        'owner.id AS owner_id',
        'owner.displayName AS "owner_displayName"',
        'owner.avatarUrl AS "owner_avatarUrl"',
        'owner.locality AS "owner_locality"',
        'owner.city AS "owner_city"',
        'CASE WHEN fav.id IS NOT NULL THEN true ELSE false END AS "currentUserFavorited"',
      ])
      .where('business.deletedAt IS NULL');

    // Filter by status (default to active for public discovery)
    if (query.status) {
      qb.andWhere('business.status = :status', { status: query.status });
    } else {
      qb.andWhere('business.status = :status', {
        status: BusinessStatus.ACTIVE,
      });
    }

    // Keyword search over name, description, and category
    if (query.query && query.query.trim()) {
      const term = `%${query.query.trim()}%`;
      qb.andWhere(
        '(business.name ILIKE :term OR business.description ILIKE :term OR business.category::text ILIKE :term)',
        { term },
      );
    }

    // Category filter
    if (query.category) {
      qb.andWhere('business.category = :category', { category: query.category });
    }

    // Locality and City text filters
    if (query.locality && query.locality.trim()) {
      qb.andWhere('business.locality ILIKE :locality', {
        locality: `%${query.locality.trim()}%`,
      });
    }
    if (query.city && query.city.trim()) {
      qb.andWhere('business.city ILIKE :city', {
        city: `%${query.city.trim()}%`,
      });
    }

    // PostGIS Spatial filtering and distance selection
    if (hasSpatialCoords) {
      qb.addSelect(
        'ROUND(ST_Distance(business.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) AS distance_meters',
      );
      qb.setParameters({
        lng: query.longitude,
        lat: query.latitude,
      });

      if (radiusMeters) {
        qb.andWhere('business.location IS NOT NULL');
        qb.andWhere(
          'ST_DWithin(business.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :radiusMeters)',
          { radiusMeters },
        );
      }
    }

    // Cursor Pagination & Sorting
    const sortBy = query.sortBy || BusinessSortBy.NEWEST;
    if (query.cursor) {
      this.applyCursorFilter(qb, query.cursor, sortBy, hasSpatialCoords);
    }

    // Deterministic ordering
    if (sortBy === BusinessSortBy.NEAREST && hasSpatialCoords) {
      qb.orderBy('distance_meters', 'ASC')
        .addOrderBy('business.createdAt', 'DESC')
        .addOrderBy('business.id', 'DESC');
    } else {
      qb.orderBy('business.createdAt', 'DESC').addOrderBy('business.id', 'DESC');
    }

    qb.limit(limit + 1);

    const rawRows: RawBusinessRow[] = await qb.getRawMany();
    const hasMore = rawRows.length > limit;
    const rows = hasMore ? rawRows.slice(0, limit) : rawRows;

    // Fetch images and services for all matched businesses in bulk
    const businessIds = rows.map((r) => r.id);
    let imagesByBusinessId: Record<string, BusinessImage[]> = {};
    let servicesByBusinessId: Record<string, BusinessService[]> = {};

    if (businessIds.length > 0) {
      const [images, services] = await Promise.all([
        this.imageRepository
          .createQueryBuilder('img')
          .where('img.businessId IN (:...businessIds)', { businessIds })
          .orderBy('img.displayOrder', 'ASC')
          .getMany(),
        this.businessServiceRepository
          .createQueryBuilder('svc')
          .where('svc.businessId IN (:...businessIds)', { businessIds })
          .orderBy('svc.createdAt', 'ASC')
          .getMany(),
      ]);

      for (const img of images) {
        if (!imagesByBusinessId[img.businessId]) {
          imagesByBusinessId[img.businessId] = [];
        }
        imagesByBusinessId[img.businessId].push(img);
      }

      for (const svc of services) {
        if (!servicesByBusinessId[svc.businessId]) {
          servicesByBusinessId[svc.businessId] = [];
        }
        servicesByBusinessId[svc.businessId].push(svc);
      }
    }

    // Next cursor
    let nextCursor: string | null = null;
    if (hasMore && rows.length > 0) {
      const last = rows[rows.length - 1];
      nextCursor = this.generateNextCursor(last, sortBy, hasSpatialCoords);
    }

    let items: BusinessResponseDto[] = rows.map((r) => {
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

      const businessImages = imagesByBusinessId[r.id] || [];
      const businessServices = servicesByBusinessId[r.id] || [];
      const operatingStatus = evaluateOperatingStatus(r.operatingHours, r.timezone);

      return {
        id: r.id,
        ownerId: r.ownerId,
        owner: {
          id: r.owner_id ?? r.ownerId,
          displayName: r.owner_displayName ?? 'Owner',
          avatarUrl: r.owner_avatarUrl ?? null,
          locality: r.owner_locality ?? r.locality ?? null,
          city: r.owner_city ?? r.city ?? null,
        },
        name: r.name,
        slug: r.slug,
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
        address: r.address ?? null,
        contactPhone: r.contactPhone ?? null,
        contactEmail: r.contactEmail ?? null,
        website: r.website ?? null,
        timezone: r.timezone ?? 'Asia/Kolkata',
        operatingHours: r.operatingHours ?? null,
        operatingStatus,
        favoriteCount: parseInt(r.favoriteCount.toString(), 10) || 0,
        isFavorited,
        isOwner: r.ownerId === userId,
        images: businessImages.map((img) => ({
          id: img.id,
          url: img.url,
          displayOrder: img.displayOrder,
        })),
        services: businessServices.map((svc) => ({
          id: svc.id,
          name: svc.name,
          description: svc.description ?? null,
          startingPrice:
            svc.startingPrice != null
              ? parseFloat(svc.startingPrice.toString())
              : null,
          currency: svc.currency,
        })),
        distance: distanceText,
        distanceMeters: distanceMetersRounded,
        createdAt: new Date(r.createdAt),
        updatedAt: new Date(r.updatedAt),
      };
    });

    // If query.openNow is specified, filter for businesses that are open now
    if (query.openNow) {
      items = items.filter((item) => item.operatingStatus.isOpen);
    }

    return {
      items,
      nextCursor,
      hasMore,
    };
  }

  /**
   * Get single business detail with owner summary and favorite state.
   */
  async getBusinessById(
    id: string,
    userId: string,
  ): Promise<BusinessResponseDto> {
    const business = await this.businessRepository.findOne({
      where: { id },
      relations: ['owner', 'images', 'services'],
    });

    if (!business || business.deletedAt) {
      throw new NotFoundException('Business listing not found.');
    }

    // Inactive/archived listings are hidden from non-owners
    if (business.status !== BusinessStatus.ACTIVE && business.ownerId !== userId) {
      throw new NotFoundException('Business listing not found or is currently inactive.');
    }

    const favorite = await this.favoriteRepository.findOne({
      where: { businessId: id, userId },
    });

    return this.mapToBusinessResponse(
      business,
      business.owner,
      !!favorite,
      business.ownerId === userId,
      business.images || [],
      business.services || [],
    );
  }

  /**
   * Update business details (Owner only).
   */
  async updateBusiness(
    id: string,
    userId: string,
    dto: UpdateBusinessDto,
  ): Promise<BusinessResponseDto> {
    const business = await this.businessRepository.findOne({
      where: { id },
      relations: ['owner', 'images', 'services'],
    });

    if (!business || business.deletedAt) {
      throw new NotFoundException('Business listing not found.');
    }

    if (business.ownerId !== userId) {
      throw new ForbiddenException('You are not authorized to update this business.');
    }

    if (dto.name !== undefined) business.name = dto.name.trim();
    if (dto.category !== undefined) business.category = dto.category;
    if (dto.description !== undefined) business.description = dto.description.trim();
    if (dto.address !== undefined) business.address = dto.address?.trim() || null;
    if (dto.locality !== undefined) business.locality = dto.locality?.trim() || null;
    if (dto.city !== undefined) business.city = dto.city?.trim() || null;
    if (dto.state !== undefined) business.state = dto.state?.trim() || null;
    if (dto.district !== undefined) business.district = dto.district?.trim() || null;
    if (dto.neighborhood !== undefined) business.neighborhood = dto.neighborhood?.trim() || null;
    if (dto.contactPhone !== undefined) business.contactPhone = dto.contactPhone?.trim() || null;
    if (dto.contactEmail !== undefined) business.contactEmail = dto.contactEmail?.trim() || null;
    if (dto.website !== undefined) business.website = dto.website?.trim() || null;
    if (dto.timezone !== undefined) business.timezone = dto.timezone?.trim() || 'Asia/Kolkata';
    if (dto.operatingHours !== undefined) business.operatingHours = dto.operatingHours;

    const updatedBusiness = await this.businessRepository.save(business);

    // Update location if coordinates provided
    if (dto.latitude !== undefined && dto.longitude !== undefined) {
      await this.businessRepository.query(
        `UPDATE "businesses"
         SET "location" = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
         WHERE "id" = $3`,
        [dto.longitude, dto.latitude, id],
      );
    }

    // Replace images if provided
    let finalImages = business.images || [];
    if (dto.images !== undefined) {
      await this.imageRepository.delete({ businessId: id });
      if (dto.images.length > 0) {
        const imageEntities = dto.images.map((img, idx) =>
          this.imageRepository.create({
            businessId: id,
            url: img.url.trim(),
            displayOrder: img.displayOrder ?? idx,
          }),
        );
        finalImages = await this.imageRepository.save(imageEntities);
      } else {
        finalImages = [];
      }
    }

    // Replace services if provided
    let finalServices = business.services || [];
    if (dto.services !== undefined) {
      await this.businessServiceRepository.delete({ businessId: id });
      if (dto.services.length > 0) {
        const serviceEntities = dto.services.map((svc) =>
          this.businessServiceRepository.create({
            businessId: id,
            name: svc.name.trim(),
            description: svc.description?.trim() || null,
            startingPrice: svc.startingPrice ?? null,
            currency: 'INR',
          }),
        );
        finalServices = await this.businessServiceRepository.save(serviceEntities);
      } else {
        finalServices = [];
      }
    }

    const favorite = await this.favoriteRepository.findOne({
      where: { businessId: id, userId },
    });

    return this.mapToBusinessResponse(
      updatedBusiness,
      business.owner,
      !!favorite,
      true,
      finalImages,
      finalServices,
    );
  }

  /**
   * Update lifecycle status of business (Owner only).
   */
  async updateBusinessStatus(
    id: string,
    userId: string,
    status: BusinessStatus,
  ): Promise<BusinessResponseDto> {
    const business = await this.businessRepository.findOne({
      where: { id },
      relations: ['owner', 'images', 'services'],
    });

    if (!business || business.deletedAt) {
      throw new NotFoundException('Business listing not found.');
    }

    if (business.ownerId !== userId) {
      throw new ForbiddenException('You are not authorized to modify the status of this business.');
    }

    business.status = status;
    const updated = await this.businessRepository.save(business);

    return this.mapToBusinessResponse(
      updated,
      business.owner,
      false,
      true,
      business.images || [],
      business.services || [],
    );
  }

  /**
   * Soft delete business listing (Owner only).
   */
  async deleteBusiness(
    id: string,
    userId: string,
  ): Promise<{ success: boolean; message: string }> {
    const business = await this.businessRepository.findOne({
      where: { id },
    });

    if (!business || business.deletedAt) {
      throw new NotFoundException('Business listing not found.');
    }

    if (business.ownerId !== userId) {
      throw new ForbiddenException('You are not authorized to delete this business.');
    }

    await this.businessRepository.softDelete({ id });
    return { success: true, message: 'Business listing deleted successfully.' };
  }

  /**
   * Get current user's businesses with cursor pagination.
   */
  async getMyBusinesses(
    userId: string,
    status?: BusinessStatus,
    cursor?: string,
    limit: number = 20,
  ): Promise<PaginatedBusinessesResponseDto> {
    const safeLimit = Math.min(limit, 50);

    const qb = this.businessRepository
      .createQueryBuilder('business')
      .leftJoinAndSelect('business.images', 'image')
      .leftJoinAndSelect('business.services', 'service')
      .leftJoinAndSelect('business.owner', 'owner')
      .where('business.ownerId = :userId', { userId })
      .andWhere('business.deletedAt IS NULL');

    if (status) {
      qb.andWhere('business.status = :status', { status });
    }

    if (cursor) {
      const decoded = Buffer.from(cursor, 'base64').toString('utf8');
      const [cursorCreatedAt, cursorId] = decoded.split(':::');
      if (cursorCreatedAt && cursorId) {
        qb.andWhere(
          '(business.createdAt < :cursorCreatedAt OR (business.createdAt = :cursorCreatedAt AND business.id < :cursorId))',
          { cursorCreatedAt: new Date(cursorCreatedAt), cursorId },
        );
      }
    }

    qb.orderBy('business.createdAt', 'DESC')
      .addOrderBy('business.id', 'DESC')
      .limit(safeLimit + 1);

    const businesses = await qb.getMany();
    const hasMore = businesses.length > safeLimit;
    const items = hasMore ? businesses.slice(0, safeLimit) : businesses;

    let nextCursor: string | null = null;
    if (hasMore && items.length > 0) {
      const last = items[items.length - 1];
      nextCursor = Buffer.from(
        `${last.createdAt.toISOString()}:::${last.id}`,
      ).toString('base64');
    }

    return {
      items: items.map((b) =>
        this.mapToBusinessResponse(
          b,
          b.owner,
          false,
          true,
          b.images || [],
          b.services || [],
        ),
      ),
      nextCursor,
      hasMore,
    };
  }

  /**
   * Toggle favorite state for a business.
   */
  async toggleFavorite(
    id: string,
    userId: string,
    favorite: boolean,
  ): Promise<{ isFavorited: boolean; favoriteCount: number }> {
    const business = await this.businessRepository.findOne({
      where: { id },
    });

    if (!business || business.deletedAt) {
      throw new NotFoundException('Business listing not found.');
    }

    const existing = await this.favoriteRepository.findOne({
      where: { businessId: id, userId },
    });

    if (favorite) {
      if (!existing) {
        const fav = this.favoriteRepository.create({
          businessId: id,
          userId,
        });
        await this.favoriteRepository.save(fav);
        await this.businessRepository.increment({ id }, 'favoriteCount', 1);
        business.favoriteCount += 1;
      }
    } else {
      if (existing) {
        await this.favoriteRepository.delete({ id: existing.id });
        if (business.favoriteCount > 0) {
          await this.businessRepository.decrement({ id }, 'favoriteCount', 1);
          business.favoriteCount -= 1;
        }
      }
    }

    return {
      isFavorited: favorite,
      favoriteCount: Math.max(0, business.favoriteCount),
    };
  }

  /**
   * Report a business for moderation review.
   */
  async reportBusiness(
    id: string,
    reporterId: string,
    dto: CreateBusinessReportDto,
  ): Promise<{ success: boolean; message: string }> {
    await this.checkRateLimit(
      `rate:business:report:${reporterId}`,
      this.maxReportsPerHour,
      3600,
      'Too many reports submitted. Please wait before submitting another report.',
    );

    const business = await this.businessRepository.findOne({
      where: { id },
    });

    if (!business || business.deletedAt) {
      throw new NotFoundException('Business listing not found.');
    }

    if (business.ownerId === reporterId) {
      throw new BadRequestException('You cannot report your own business listing.');
    }

    const existingReport = await this.reportRepository.findOne({
      where: { businessId: id, reporterId },
    });

    if (existingReport) {
      throw new ConflictException('You have already submitted a report for this business.');
    }

    const report = this.reportRepository.create({
      businessId: id,
      reporterId,
      reason: dto.reason,
      details: dto.details?.trim() || null,
      status: BusinessReportStatus.PENDING,
    });

    await this.reportRepository.save(report);
    return {
      success: true,
      message: 'Report submitted successfully. Our local community moderators will review it.',
    };
  }

  /**
   * List all centralized business categories.
   */
  getCategories(): Array<{ id: BusinessCategory; label: string; description: string }> {
    return [
      { id: BusinessCategory.FOOD_DINING, label: 'Food & Dining', description: 'Restaurants, cafes, bakeries, eateries' },
      { id: BusinessCategory.GROCERY, label: 'Grocery & Essentials', description: 'Kirana stores, supermarkets, daily needs' },
      { id: BusinessCategory.SHOPPING, label: 'Shopping & Retail', description: 'Clothing, fashion, lifestyle stores' },
      { id: BusinessCategory.HEALTH, label: 'Health & Wellness', description: 'Pharmacies, clinics, diagnostic centers' },
      { id: BusinessCategory.BEAUTY, label: 'Beauty & Salon', description: 'Salons, spas, grooming centers' },
      { id: BusinessCategory.FITNESS, label: 'Fitness & Sports', description: 'Gyms, yoga centers, sports complexes' },
      { id: BusinessCategory.EDUCATION, label: 'Education & Coaching', description: 'Tuitions, coaching centers, libraries' },
      { id: BusinessCategory.ELECTRONICS, label: 'Electronics & Gadgets', description: 'Mobile, computer, and appliance shops' },
      { id: BusinessCategory.HOME_REPAIR, label: 'Home & Hardware', description: 'Hardware, paint, sanitary, electrical shops' },
      { id: BusinessCategory.AUTOMOTIVE, label: 'Automotive', description: 'Workshops, spare parts, tyre repair' },
      { id: BusinessCategory.PROFESSIONAL, label: 'Professional Services', description: 'CA, legal, printing, courier hubs' },
      { id: BusinessCategory.OTHER, label: 'Other Local Business', description: 'General neighborhood businesses' },
    ];
  }

  /**
   * Maps entities to privacy-safe public DTO.
   */
  private mapToBusinessResponse(
    b: Business,
    owner: User,
    isFavorited: boolean,
    isOwner: boolean,
    images: BusinessImage[],
    services: BusinessService[],
  ): BusinessResponseDto {
    const operatingStatus = evaluateOperatingStatus(b.operatingHours, b.timezone);

    return {
      id: b.id,
      ownerId: b.ownerId,
      owner: {
        id: owner?.id ?? b.ownerId,
        displayName: owner?.displayName ?? 'Neighbor',
        avatarUrl: owner?.avatarUrl ?? null,
        locality: owner?.locality ?? b.locality ?? null,
        city: owner?.city ?? b.city ?? null,
      },
      name: b.name,
      slug: b.slug,
      description: b.description,
      category: b.category,
      status: b.status,
      verificationStatus: b.verificationStatus,
      countryCode: b.countryCode ?? 'IN',
      state: b.state ?? null,
      district: b.district ?? null,
      city: b.city ?? null,
      locality: b.locality ?? null,
      neighborhood: b.neighborhood ?? null,
      address: b.address ?? null,
      contactPhone: b.contactPhone ?? null,
      contactEmail: b.contactEmail ?? null,
      website: b.website ?? null,
      timezone: b.timezone ?? 'Asia/Kolkata',
      operatingHours: b.operatingHours ?? null,
      operatingStatus,
      favoriteCount: b.favoriteCount ?? 0,
      isFavorited,
      isOwner,
      images: images.map((img) => ({
        id: img.id,
        url: img.url,
        displayOrder: img.displayOrder,
      })),
      services: services.map((svc) => ({
        id: svc.id,
        name: svc.name,
        description: svc.description ?? null,
        startingPrice:
          svc.startingPrice != null
            ? parseFloat(svc.startingPrice.toString())
            : null,
        currency: svc.currency,
      })),
      distance: null,
      distanceMeters: null,
      createdAt: b.createdAt,
      updatedAt: b.updatedAt,
    };
  }

  private applyCursorFilter(
    qb: any,
    cursor: string,
    sortBy: BusinessSortBy,
    hasSpatialCoords: boolean,
  ): void {
    try {
      const decoded = Buffer.from(cursor, 'base64').toString('utf8');
      const parts = decoded.split(':::');

      if (sortBy === BusinessSortBy.NEAREST && hasSpatialCoords && parts.length === 3) {
        const [dist, createdAt, id] = parts;
        qb.andWhere(
          `(ROUND(ST_Distance(business.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) > :dist
           OR (ROUND(ST_Distance(business.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) = :dist AND business.createdAt < :createdAt)
           OR (ROUND(ST_Distance(business.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) = :dist AND business.createdAt = :createdAt AND business.id < :id))`,
          { dist: parseFloat(dist), createdAt: new Date(createdAt), id },
        );
      } else if (parts.length >= 2) {
        const [createdAt, id] = parts;
        qb.andWhere(
          '(business.createdAt < :createdAt OR (business.createdAt = :createdAt AND business.id < :id))',
          { createdAt: new Date(createdAt), id },
        );
      }
    } catch (e) {
      this.logger.warn(`Failed to parse pagination cursor: ${cursor}`, e);
    }
  }

  private generateNextCursor(
    row: RawBusinessRow,
    sortBy: BusinessSortBy,
    hasSpatialCoords: boolean,
  ): string {
    const createdAtStr =
      row.createdAt instanceof Date
        ? row.createdAt.toISOString()
        : new Date(row.createdAt).toISOString();

    if (
      sortBy === BusinessSortBy.NEAREST &&
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
      // If Redis is unavailable in non-strict mode, log warning and allow request
      this.logger.warn(`Redis rate limit check skipped due to error: ${err}`);
    }
  }
}
