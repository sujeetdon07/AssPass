import { BusinessCategory, BusinessStatus, BusinessVerificationStatus } from '../entities/business.entity.js';
import { OperatingStatusResult } from '../utils/operating-hours.util.js';

export interface BusinessOwnerSummaryDto {
  id: string;
  displayName: string;
  avatarUrl: string | null;
  locality: string | null;
  city: string | null;
}

export interface BusinessImageDto {
  id: string;
  url: string;
  displayOrder: number;
}

export interface BusinessServiceOfferingDto {
  id: string;
  name: string;
  description: string | null;
  startingPrice: number | null;
  currency: string;
}

export class BusinessResponseDto {
  id!: string;
  ownerId!: string;
  owner!: BusinessOwnerSummaryDto;
  name!: string;
  slug!: string;
  description!: string;
  category!: BusinessCategory;
  status!: BusinessStatus;
  verificationStatus!: BusinessVerificationStatus;
  countryCode!: string;
  state!: string | null;
  district!: string | null;
  city!: string | null;
  locality!: string | null;
  neighborhood!: string | null;
  address!: string | null;
  contactPhone!: string | null;
  contactEmail!: string | null;
  website!: string | null;
  timezone!: string;
  operatingHours!: any;
  operatingStatus!: OperatingStatusResult;
  favoriteCount!: number;
  isFavorited!: boolean;
  isOwner!: boolean;
  images!: BusinessImageDto[];
  services!: BusinessServiceOfferingDto[];
  distance?: string | null;
  distanceMeters?: number | null;
  createdAt!: Date;
  updatedAt!: Date;
}

export class PaginatedBusinessesResponseDto {
  items!: BusinessResponseDto[];
  nextCursor!: string | null;
  hasMore!: boolean;
}
