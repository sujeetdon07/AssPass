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
  MarketplaceListing,
  MarketplaceListingStatus,
  MarketplaceCategory,
  MarketplaceCondition,
} from '../entities/marketplace-listing.entity.js';
import { MarketplaceListingImage } from '../entities/marketplace-listing-image.entity.js';
import { MarketplaceFavorite } from '../entities/marketplace-favorite.entity.js';
import {
  MarketplaceReport,
  MarketplaceReportStatus,
} from '../entities/marketplace-report.entity.js';
import { User } from '../../users/entities/user.entity.js';
import { RedisService } from '../../../database/redis.service.js';
import { getLocalityCentroid } from '../../localities/utils/locality-centroid.util.js';
import { formatPrivacySafeDistance } from '../../nearby/dto/nearby-post-response.dto.js';
import { CreateListingDto } from '../dto/create-listing.dto.js';
import { UpdateListingDto } from '../dto/update-listing.dto.js';
import {
  GetListingsQueryDto,
  MarketplaceSortBy,
} from '../dto/get-listings-query.dto.js';
import { CreateMarketplaceReportDto } from '../dto/create-marketplace-report.dto.js';
import {
  MarketplaceListingResponseDto,
  PaginatedMarketplaceListingsResponseDto,
} from '../dto/marketplace-listing-response.dto.js';

interface RawListingRow {
  id: string;
  sellerId: string;
  title: string;
  description: string;
  category: MarketplaceCategory;
  price: string | number;
  currency: string;
  condition: MarketplaceCondition;
  status: MarketplaceListingStatus;
  countryCode: string;
  state: string | null;
  district: string | null;
  city: string | null;
  locality: string | null;
  neighborhood: string | null;
  favoriteCount: string | number;
  createdAt: Date | string;
  updatedAt: Date | string;
  seller_id: string;
  seller_displayName: string | null;
  seller_avatarUrl: string | null;
  seller_locality: string | null;
  seller_city: string | null;
  currentUserFavorited: boolean | string | number;
  distance_meters?: number | string | null;
}

@Injectable()
export class MarketplaceService {
  private readonly logger = new Logger(MarketplaceService.name);
  private readonly maxCreatePerHour = 20;
  private readonly maxReportsPerHour = 10;
  private readonly maxSearchesPerMinute = 60;

  constructor(
    @InjectRepository(MarketplaceListing)
    private readonly listingRepository: Repository<MarketplaceListing>,
    @InjectRepository(MarketplaceListingImage)
    private readonly imageRepository: Repository<MarketplaceListingImage>,
    @InjectRepository(MarketplaceFavorite)
    private readonly favoriteRepository: Repository<MarketplaceFavorite>,
    @InjectRepository(MarketplaceReport)
    private readonly reportRepository: Repository<MarketplaceReport>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly redisService: RedisService,
  ) {}

  /**
   * Create a new marketplace listing with server-side validation and centroid resolution.
   */
  async createListing(
    userId: string,
    dto: CreateListingDto,
  ): Promise<MarketplaceListingResponseDto> {
    await this.checkRateLimit(
      `rate:marketplace:create:${userId}`,
      this.maxCreatePerHour,
      3600,
      'Too many listings created. Please wait before creating another listing.',
    );

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User profile not found.');
    }

    const locality = dto.locality?.trim() || user.locality || null;
    const city = dto.city?.trim() || user.city || null;
    const coords = getLocalityCentroid(locality, city);

    const listing = this.listingRepository.create({
      sellerId: userId,
      title: dto.title.trim(),
      description: dto.description.trim(),
      category: dto.category,
      price: dto.price,
      currency: dto.currency ? dto.currency.trim().toUpperCase() : 'INR',
      condition: dto.condition,
      status: MarketplaceListingStatus.ACTIVE,
      countryCode: dto.countryCode?.trim() || user.countryCode || 'IN',
      state: dto.state?.trim() || user.state || null,
      district: dto.district?.trim() || user.district || null,
      city,
      locality,
      neighborhood: dto.neighborhood?.trim() || user.neighborhood || null,
      favoriteCount: 0,
    });

    const savedListing = await this.listingRepository.save(listing);

    // Update PostGIS geometry location point safely using SQL query
    await this.listingRepository.query(
      `UPDATE "marketplace_listings"
       SET "location" = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
       WHERE "id" = $3`,
      [coords.longitude, coords.latitude, savedListing.id],
    );

    // Save image metadata if provided
    let savedImages: MarketplaceListingImage[] = [];
    if (dto.images && dto.images.length > 0) {
      const imageEntities = dto.images.map((img, idx) =>
        this.imageRepository.create({
          listingId: savedListing.id,
          url: img.url.trim(),
          displayOrder: img.displayOrder ?? idx,
        }),
      );
      savedImages = await this.imageRepository.save(imageEntities);
    }

    return this.mapToListingResponse(savedListing, user, false, true, savedImages);
  }

  /**
   * Discover and search marketplace listings with filters, PostGIS radius, and cursor pagination.
   */
  async getListings(
    userId: string,
    query: GetListingsQueryDto,
  ): Promise<PaginatedMarketplaceListingsResponseDto> {
    await this.checkRateLimit(
      `rate:marketplace:search:${userId}`,
      this.maxSearchesPerMinute,
      60,
      'Too many search requests. Please wait a moment.',
    );

    const limit = Math.min(query.limit || 20, 50);
    const hasSpatialCoords =
      query.latitude !== undefined && query.longitude !== undefined;
    const radiusMeters = query.radius ? query.radius * 1000 : null;

    const qb = this.listingRepository
      .createQueryBuilder('listing')
      .leftJoin('users', 'seller', 'seller.id = listing.sellerId')
      .leftJoin(
        'marketplace_favorites',
        'fav',
        'fav.listingId = listing.id AND fav.userId = :userId',
        { userId },
      )
      .select([
        'listing.id AS id',
        'listing.sellerId AS "sellerId"',
        'listing.title AS title',
        'listing.description AS description',
        'listing.category AS category',
        'listing.price AS price',
        'listing.currency AS currency',
        'listing.condition AS condition',
        'listing.status AS status',
        'listing.countryCode AS "countryCode"',
        'listing.state AS state',
        'listing.district AS district',
        'listing.city AS city',
        'listing.locality AS locality',
        'listing.neighborhood AS neighborhood',
        'listing.favoriteCount AS "favoriteCount"',
        'listing.createdAt AS "createdAt"',
        'listing.updatedAt AS "updatedAt"',
        'seller.id AS seller_id',
        'seller.displayName AS "seller_displayName"',
        'seller.avatarUrl AS "seller_avatarUrl"',
        'seller.locality AS "seller_locality"',
        'seller.city AS "seller_city"',
        'CASE WHEN fav.id IS NOT NULL THEN true ELSE false END AS "currentUserFavorited"',
      ])
      .where('listing.deletedAt IS NULL');

    // Filter by status (default to active for public discovery)
    if (query.status) {
      qb.andWhere('listing.status = :status', { status: query.status });
    } else {
      qb.andWhere('listing.status = :status', {
        status: MarketplaceListingStatus.ACTIVE,
      });
    }

    // Keyword search over title & description
    if (query.query && query.query.trim()) {
      const term = `%${query.query.trim()}%`;
      qb.andWhere(
        '(listing.title ILIKE :term OR listing.description ILIKE :term)',
        { term },
      );
    }

    // Category filter
    if (query.category) {
      qb.andWhere('listing.category = :category', { category: query.category });
    }

    // Condition filter
    if (query.condition) {
      qb.andWhere('listing.condition = :condition', {
        condition: query.condition,
      });
    }

    // Price range filters
    if (query.minPrice !== undefined) {
      qb.andWhere('listing.price >= :minPrice', { minPrice: query.minPrice });
    }
    if (query.maxPrice !== undefined) {
      qb.andWhere('listing.price <= :maxPrice', { maxPrice: query.maxPrice });
    }

    // Locality and City text filters
    if (query.locality && query.locality.trim()) {
      qb.andWhere('listing.locality ILIKE :locality', {
        locality: `%${query.locality.trim()}%`,
      });
    }
    if (query.city && query.city.trim()) {
      qb.andWhere('listing.city ILIKE :city', {
        city: `%${query.city.trim()}%`,
      });
    }

    // PostGIS Spatial filtering and distance selection
    if (hasSpatialCoords) {
      qb.addSelect(
        'ROUND(ST_Distance(listing.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) AS distance_meters',
      );
      qb.setParameters({
        lng: query.longitude,
        lat: query.latitude,
      });

      if (radiusMeters) {
        qb.andWhere('listing.location IS NOT NULL');
        qb.andWhere(
          'ST_DWithin(listing.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :radiusMeters)',
          { radiusMeters },
        );
      }
    }

    // Cursor Pagination & Sorting
    const sortBy = query.sortBy || MarketplaceSortBy.NEWEST;

    if (query.cursor) {
      this.applyCursorFilter(qb, query.cursor, sortBy, hasSpatialCoords);
    }

    // Deterministic ordering
    if (sortBy === MarketplaceSortBy.NEAREST && hasSpatialCoords) {
      qb.orderBy('distance_meters', 'ASC')
        .addOrderBy('listing.createdAt', 'DESC')
        .addOrderBy('listing.id', 'DESC');
    } else if (sortBy === MarketplaceSortBy.PRICE_ASC) {
      qb.orderBy('listing.price', 'ASC')
        .addOrderBy('listing.createdAt', 'DESC')
        .addOrderBy('listing.id', 'DESC');
    } else if (sortBy === MarketplaceSortBy.PRICE_DESC) {
      qb.orderBy('listing.price', 'DESC')
        .addOrderBy('listing.createdAt', 'DESC')
        .addOrderBy('listing.id', 'DESC');
    } else {
      qb.orderBy('listing.createdAt', 'DESC').addOrderBy('listing.id', 'DESC');
    }

    qb.limit(limit + 1);

    const rawRows: RawListingRow[] = await qb.getRawMany();
    const hasMore = rawRows.length > limit;
    const rows = hasMore ? rawRows.slice(0, limit) : rawRows;

    // Fetch images for all matched listings efficiently
    const listingIds = rows.map((r) => r.id);
    let imagesByListingId: Record<string, MarketplaceListingImage[]> = {};
    if (listingIds.length > 0) {
      const images = await this.imageRepository
        .createQueryBuilder('img')
        .where('img.listingId IN (:...listingIds)', { listingIds })
        .orderBy('img.displayOrder', 'ASC')
        .getMany();

      for (const img of images) {
        if (!imagesByListingId[img.listingId]) {
          imagesByListingId[img.listingId] = [];
        }
        imagesByListingId[img.listingId].push(img);
      }
    }

    // Generate next cursor
    let nextCursor: string | null = null;
    if (hasMore && rows.length > 0) {
      const last = rows[rows.length - 1];
      nextCursor = this.generateNextCursor(last, sortBy, hasSpatialCoords);
    }

    const items: MarketplaceListingResponseDto[] = rows.map((r) => {
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

      const listingImages = imagesByListingId[r.id] || [];

      return {
        id: r.id,
        sellerId: r.sellerId,
        seller: {
          id: r.seller_id ?? r.sellerId,
          displayName: r.seller_displayName ?? 'Neighbor',
          avatarUrl: r.seller_avatarUrl ?? null,
          locality: r.seller_locality ?? r.locality ?? null,
          city: r.seller_city ?? r.city ?? null,
        },
        title: r.title,
        description: r.description,
        category: r.category,
        price: parseFloat(r.price.toString()),
        currency: r.currency,
        condition: r.condition,
        status: r.status,
        countryCode: r.countryCode ?? 'IN',
        state: r.state ?? null,
        district: r.district ?? null,
        city: r.city ?? null,
        locality: r.locality ?? null,
        neighborhood: r.neighborhood ?? null,
        favoriteCount: parseInt(r.favoriteCount.toString(), 10) || 0,
        isFavorited,
        isOwner: r.sellerId === userId,
        images: listingImages.map((img) => ({
          id: img.id,
          url: img.url,
          displayOrder: img.displayOrder,
        })),
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
   * Get single listing detail with full seller summary and favorite status.
   */
  async getListingById(
    id: string,
    userId: string,
  ): Promise<MarketplaceListingResponseDto> {
    const listing = await this.listingRepository.findOne({
      where: { id },
      relations: ['seller', 'images'],
    });

    if (!listing || listing.deletedAt) {
      throw new NotFoundException('Marketplace listing not found.');
    }

    const favorite = await this.favoriteRepository.findOne({
      where: { listingId: id, userId },
    });

    return this.mapToListingResponse(
      listing,
      listing.seller,
      !!favorite,
      listing.sellerId === userId,
      listing.images || [],
    );
  }

  /**
   * Get current user's listings (active, sold, or archived) with cursor pagination.
   */
  async getMyListings(
    userId: string,
    status?: MarketplaceListingStatus,
    cursor?: string,
    limit: number = 20,
  ): Promise<PaginatedMarketplaceListingsResponseDto> {
    const safeLimit = Math.min(limit, 50);

    const qb = this.listingRepository
      .createQueryBuilder('listing')
      .leftJoinAndSelect('listing.images', 'image')
      .leftJoinAndSelect('listing.seller', 'seller')
      .where('listing.sellerId = :userId', { userId })
      .andWhere('listing.deletedAt IS NULL');

    if (status) {
      qb.andWhere('listing.status = :status', { status });
    }

    if (cursor) {
      try {
        const decoded = Buffer.from(cursor, 'base64').toString('utf8');
        const [cDateStr, cId] = decoded.split(';');
        const cDate = new Date(cDateStr);
        if (!isNaN(cDate.getTime()) && cId) {
          qb.andWhere(
            '(listing.createdAt < :cDate OR (listing.createdAt = :cDate AND listing.id < :cId))',
            { cDate, cId },
          );
        }
      } catch {
        this.logger.warn(`Malformed cursor for my listings: ${cursor}`);
      }
    }

    qb.orderBy('listing.createdAt', 'DESC')
      .addOrderBy('listing.id', 'DESC')
      .limit(safeLimit + 1);

    const rows = await qb.getMany();
    const hasMore = rows.length > safeLimit;
    const items = hasMore ? rows.slice(0, safeLimit) : rows;

    let nextCursor: string | null = null;
    if (hasMore && items.length > 0) {
      const last = items[items.length - 1];
      nextCursor = Buffer.from(
        `${last.createdAt.toISOString()};${last.id}`,
      ).toString('base64');
    }

    return {
      items: items.map((l) =>
        this.mapToListingResponse(l, l.seller, false, true, l.images || []),
      ),
      nextCursor,
      hasMore,
    };
  }

  /**
   * Update an existing listing. Enforces backend ownership verification.
   */
  async updateListing(
    id: string,
    userId: string,
    dto: UpdateListingDto,
  ): Promise<MarketplaceListingResponseDto> {
    const listing = await this.listingRepository.findOne({
      where: { id },
      relations: ['seller', 'images'],
    });

    if (!listing || listing.deletedAt) {
      throw new NotFoundException('Marketplace listing not found.');
    }

    if (listing.sellerId !== userId) {
      throw new ForbiddenException(
        'You do not have permission to modify this listing.',
      );
    }

    if (dto.title !== undefined) listing.title = dto.title.trim();
    if (dto.description !== undefined) listing.description = dto.description.trim();
    if (dto.category !== undefined) listing.category = dto.category;
    if (dto.price !== undefined) listing.price = dto.price;
    if (dto.condition !== undefined) listing.condition = dto.condition;
    if (dto.state !== undefined) listing.state = dto.state?.trim() || null;
    if (dto.city !== undefined) listing.city = dto.city?.trim() || null;
    if (dto.locality !== undefined) listing.locality = dto.locality?.trim() || null;
    if (dto.neighborhood !== undefined)
      listing.neighborhood = dto.neighborhood?.trim() || null;

    const savedListing = await this.listingRepository.save(listing);

    // If locality or city changed, update PostGIS centroid point
    if (dto.locality !== undefined || dto.city !== undefined) {
      const coords = getLocalityCentroid(savedListing.locality, savedListing.city);
      await this.listingRepository.query(
        `UPDATE "marketplace_listings"
         SET "location" = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
         WHERE "id" = $3`,
        [coords.longitude, coords.latitude, savedListing.id],
      );
    }

    // Update images if provided
    let updatedImages = listing.images || [];
    if (dto.images !== undefined) {
      await this.imageRepository.delete({ listingId: id });
      if (dto.images.length > 0) {
        const imageEntities = dto.images.map((img, idx) =>
          this.imageRepository.create({
            listingId: id,
            url: img.url.trim(),
            displayOrder: img.displayOrder ?? idx,
          }),
        );
        updatedImages = await this.imageRepository.save(imageEntities);
      } else {
        updatedImages = [];
      }
    }

    return this.mapToListingResponse(
      savedListing,
      listing.seller,
      false,
      true,
      updatedImages,
    );
  }

  /**
   * Update listing status (active, sold, archived). Enforces ownership.
   */
  async updateListingStatus(
    id: string,
    userId: string,
    status: MarketplaceListingStatus,
  ): Promise<MarketplaceListingResponseDto> {
    const listing = await this.listingRepository.findOne({
      where: { id },
      relations: ['seller', 'images'],
    });

    if (!listing || listing.deletedAt) {
      throw new NotFoundException('Marketplace listing not found.');
    }

    if (listing.sellerId !== userId) {
      throw new ForbiddenException(
        'You do not have permission to change the status of this listing.',
      );
    }

    listing.status = status;
    const saved = await this.listingRepository.save(listing);

    return this.mapToListingResponse(
      saved,
      listing.seller,
      false,
      true,
      listing.images || [],
    );
  }

  /**
   * Soft delete a listing. Enforces backend ownership verification.
   */
  async deleteListing(
    id: string,
    userId: string,
  ): Promise<{ message: string }> {
    const listing = await this.listingRepository.findOne({ where: { id } });

    if (!listing || listing.deletedAt) {
      throw new NotFoundException('Marketplace listing not found.');
    }

    if (listing.sellerId !== userId) {
      throw new ForbiddenException(
        'You do not have permission to delete this listing.',
      );
    }

    await this.listingRepository.softDelete(id);
    return { message: 'Listing deleted successfully.' };
  }

  /**
   * Favorite / Unfavorite a listing idempotently.
   */
  async toggleFavorite(
    id: string,
    userId: string,
    shouldFavorite: boolean,
  ): Promise<{ isFavorited: boolean; favoriteCount: number }> {
    const listing = await this.listingRepository.findOne({ where: { id } });

    if (!listing || listing.deletedAt) {
      throw new NotFoundException('Marketplace listing not found.');
    }

    const existingFav = await this.favoriteRepository.findOne({
      where: { listingId: id, userId },
    });

    if (shouldFavorite) {
      if (!existingFav) {
        const fav = this.favoriteRepository.create({ listingId: id, userId });
        await this.favoriteRepository.save(fav);
        await this.listingRepository.increment({ id }, 'favoriteCount', 1);
        listing.favoriteCount += 1;
      }
      return { isFavorited: true, favoriteCount: listing.favoriteCount };
    } else {
      if (existingFav) {
        await this.favoriteRepository.remove(existingFav);
        await this.listingRepository.decrement({ id }, 'favoriteCount', 1);
        listing.favoriteCount = Math.max(0, listing.favoriteCount - 1);
      }
      return { isFavorited: false, favoriteCount: listing.favoriteCount };
    }
  }

  /**
   * Report a listing for trust & safety review with Redis rate-limiting and duplicate prevention.
   */
  async reportListing(
    id: string,
    reporterId: string,
    dto: CreateMarketplaceReportDto,
  ): Promise<{ message: string }> {
    const listing = await this.listingRepository.findOne({ where: { id } });

    if (!listing || listing.deletedAt) {
      throw new NotFoundException('Marketplace listing not found.');
    }

    if (listing.sellerId === reporterId) {
      throw new BadRequestException('You cannot report your own listing.');
    }

    await this.checkRateLimit(
      `rate:marketplace:report:${reporterId}`,
      this.maxReportsPerHour,
      3600,
      'Too many reports submitted. Please wait before reporting again.',
    );

    const existing = await this.reportRepository.findOne({
      where: { listingId: id, reporterId },
    });

    if (existing) {
      throw new ConflictException(
        'You have already submitted a report for this listing.',
      );
    }

    const report = this.reportRepository.create({
      listingId: id,
      reporterId,
      reason: dto.reason,
      details: dto.details?.trim() || null,
      status: MarketplaceReportStatus.PENDING,
    });

    await this.reportRepository.save(report);
    return { message: 'Thank you. Your report has been submitted for review.' };
  }

  // ── Helper Utilities ────────────────────────────────────────────────────────

  private applyCursorFilter(
    qb: any,
    cursor: string,
    sortBy: MarketplaceSortBy,
    hasSpatialCoords: boolean,
  ): void {
    try {
      const decoded = Buffer.from(cursor, 'base64').toString('utf8');
      const parts = decoded.split(';');

      if (sortBy === MarketplaceSortBy.NEAREST && hasSpatialCoords) {
        const [cDistStr, cDateStr, cId] = parts;
        const cDist = parseFloat(cDistStr);
        const cDate = new Date(cDateStr);
        if (!isNaN(cDist) && !isNaN(cDate.getTime()) && cId) {
          qb.andWhere(
            `(
              ROUND(ST_Distance(listing.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) > :cDist
              OR (
                ROUND(ST_Distance(listing.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) = :cDist
                AND (listing.createdAt < :cDate OR (listing.createdAt = :cDate AND listing.id < :cId))
              )
            )`,
            { cDist, cDate, cId },
          );
        }
      } else if (
        sortBy === MarketplaceSortBy.PRICE_ASC ||
        sortBy === MarketplaceSortBy.PRICE_DESC
      ) {
        const [cPriceStr, cDateStr, cId] = parts;
        const cPrice = parseFloat(cPriceStr);
        const cDate = new Date(cDateStr);
        if (!isNaN(cPrice) && !isNaN(cDate.getTime()) && cId) {
          const comp = sortBy === MarketplaceSortBy.PRICE_ASC ? '>' : '<';
          qb.andWhere(
            `(
              listing.price ${comp} :cPrice
              OR (
                listing.price = :cPrice
                AND (listing.createdAt < :cDate OR (listing.createdAt = :cDate AND listing.id < :cId))
              )
            )`,
            { cPrice, cDate, cId },
          );
        }
      } else {
        const [cDateStr, cId] = parts;
        const cDate = new Date(cDateStr);
        if (!isNaN(cDate.getTime()) && cId) {
          qb.andWhere(
            '(listing.createdAt < :cDate OR (listing.createdAt = :cDate AND listing.id < :cId))',
            { cDate, cId },
          );
        }
      }
    } catch {
      this.logger.warn(`Malformed cursor in getListings: ${cursor}`);
    }
  }

  private generateNextCursor(
    last: RawListingRow,
    sortBy: MarketplaceSortBy,
    hasSpatialCoords: boolean,
  ): string {
    const cDate = new Date(last.createdAt).toISOString();
    if (
      sortBy === MarketplaceSortBy.NEAREST &&
      hasSpatialCoords &&
      last.distance_meters !== undefined &&
      last.distance_meters !== null
    ) {
      const dist = parseFloat(last.distance_meters.toString());
      return Buffer.from(`${dist};${cDate};${last.id}`).toString('base64');
    } else if (
      sortBy === MarketplaceSortBy.PRICE_ASC ||
      sortBy === MarketplaceSortBy.PRICE_DESC
    ) {
      const price = parseFloat(last.price.toString());
      return Buffer.from(`${price};${cDate};${last.id}`).toString('base64');
    } else {
      return Buffer.from(`${cDate};${last.id}`).toString('base64');
    }
  }

  private mapToListingResponse(
    listing: MarketplaceListing,
    seller: User | null,
    isFavorited: boolean,
    isOwner: boolean,
    images: MarketplaceListingImage[],
  ): MarketplaceListingResponseDto {
    return {
      id: listing.id,
      sellerId: listing.sellerId,
      seller: {
        id: seller?.id ?? listing.sellerId,
        displayName: seller?.displayName ?? 'Neighbor',
        avatarUrl: seller?.avatarUrl ?? null,
        locality: seller?.locality ?? listing.locality ?? null,
        city: seller?.city ?? listing.city ?? null,
      },
      title: listing.title,
      description: listing.description,
      category: listing.category,
      price:
        typeof listing.price === 'string'
          ? parseFloat(listing.price)
          : listing.price,
      currency: listing.currency,
      condition: listing.condition,
      status: listing.status,
      countryCode: listing.countryCode ?? 'IN',
      state: listing.state ?? null,
      district: listing.district ?? null,
      city: listing.city ?? null,
      locality: listing.locality ?? null,
      neighborhood: listing.neighborhood ?? null,
      favoriteCount: listing.favoriteCount ?? 0,
      isFavorited,
      isOwner,
      images: (images || []).map((img) => ({
        id: img.id,
        url: img.url,
        displayOrder: img.displayOrder,
      })),
      createdAt: listing.createdAt,
      updatedAt: listing.updatedAt,
    };
  }

  private async checkRateLimit(
    key: string,
    maxLimit: number,
    windowSeconds: number,
    errorMessage: string,
  ): Promise<void> {
    try {
      const current = await this.redisService.get(key);
      const count = current ? parseInt(current, 10) : 0;
      if (count >= maxLimit) {
        throw new HttpException(
          {
            code: 'RATE_LIMITED',
            message: errorMessage,
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      if (count === 0) {
        await this.redisService.set(key, '1', windowSeconds);
      } else {
        const ttl = await this.redisService.ttl(key);
        await this.redisService.set(
          key,
          (count + 1).toString(),
          ttl > 0 ? ttl : windowSeconds,
        );
      }
    } catch (err) {
      if (err instanceof HttpException) throw err;
      this.logger.warn(`Redis rate limit check error for ${key}: ${err}`);
    }
  }
}
