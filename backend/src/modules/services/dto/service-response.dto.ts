import { ServiceCategory, ServiceStatus, ServiceVerificationStatus } from '../entities/service-listing.entity.js';

export interface ServiceProviderSummaryDto {
  id: string;
  displayName: string;
  avatarUrl: string | null;
  locality: string | null;
  city: string | null;
}

export class ServiceResponseDto {
  id!: string;
  ownerId!: string;
  owner!: ServiceProviderSummaryDto;
  title!: string;
  description!: string;
  category!: ServiceCategory;
  status!: ServiceStatus;
  verificationStatus!: ServiceVerificationStatus;
  countryCode!: string;
  state!: string | null;
  district!: string | null;
  city!: string | null;
  locality!: string | null;
  neighborhood!: string | null;
  serviceRadiusKm!: number;
  contactPhone!: string | null;
  contactEmail!: string | null;
  experienceYears!: number | null;
  availability!: string | null;
  startingPrice!: number | null;
  currency!: string;
  favoriteCount!: number;
  isFavorited!: boolean;
  isOwner!: boolean;
  distance?: string | null;
  distanceMeters?: number | null;
  createdAt!: Date;
  updatedAt!: Date;
}

export class PaginatedServicesResponseDto {
  items!: ServiceResponseDto[];
  nextCursor!: string | null;
  hasMore!: boolean;
}
