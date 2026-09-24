import {
  IsString,
  MaxLength,
  MinLength,
  IsEnum,
  IsOptional,
  IsNumber,
  Min,
  Max,
  IsArray,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { BusinessCategory } from '../entities/business.entity.js';
import { BusinessServiceInputDto, BusinessImageInputDto } from './create-business.dto.js';

export class UpdateBusinessDto {
  @ApiPropertyOptional({ description: 'Name of the business' })
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  name?: string;

  @ApiPropertyOptional({ enum: BusinessCategory, description: 'Primary business category' })
  @IsOptional()
  @IsEnum(BusinessCategory)
  category?: BusinessCategory;

  @ApiPropertyOptional({ description: 'Detailed description of the business' })
  @IsOptional()
  @IsString()
  @MinLength(10)
  @MaxLength(3000)
  description?: string;

  @ApiPropertyOptional({ description: 'Street/Public storefront address' })
  @IsOptional()
  @IsString()
  @MaxLength(250)
  address?: string;

  @ApiPropertyOptional({ description: 'Locality name' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  locality?: string;

  @ApiPropertyOptional({ description: 'City name' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @ApiPropertyOptional({ description: 'State name' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  state?: string;

  @ApiPropertyOptional({ description: 'District name' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  district?: string;

  @ApiPropertyOptional({ description: 'Neighborhood name' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  neighborhood?: string;

  @ApiPropertyOptional({ description: 'Public Storefront Latitude' })
  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiPropertyOptional({ description: 'Public Storefront Longitude' })
  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @ApiPropertyOptional({ description: 'Public Business Contact Phone' })
  @IsOptional()
  @IsString()
  @MaxLength(25)
  contactPhone?: string;

  @ApiPropertyOptional({ description: 'Public Business Email' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  contactEmail?: string;

  @ApiPropertyOptional({ description: 'Public Website or social page URL' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  website?: string;

  @ApiPropertyOptional({ description: 'IANA Timezone' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  timezone?: string;

  @ApiPropertyOptional({ description: 'Structured Weekly Operating Hours' })
  @IsOptional()
  operatingHours?: any;

  @ApiPropertyOptional({ type: [BusinessServiceInputDto], description: 'Services or specialties offered' })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BusinessServiceInputDto)
  services?: BusinessServiceInputDto[];

  @ApiPropertyOptional({ type: [BusinessImageInputDto], description: 'Storefront or showcase images' })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BusinessImageInputDto)
  images?: BusinessImageInputDto[];
}
