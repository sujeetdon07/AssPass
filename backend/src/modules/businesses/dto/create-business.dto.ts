import {
  IsString,
  IsNotEmpty,
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
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { BusinessCategory } from '../entities/business.entity.js';

export class BusinessServiceInputDto {
  @ApiProperty({ description: 'Service name', example: 'Haircut & Styling' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name!: string;

  @ApiPropertyOptional({ description: 'Description of service offering' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiPropertyOptional({ description: 'Starting price', example: 350.0 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  startingPrice?: number;
}

export class BusinessImageInputDto {
  @ApiProperty({ description: 'Public URL to the image' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  url!: string;

  @ApiPropertyOptional({ description: 'Display order', default: 0 })
  @IsOptional()
  @IsNumber()
  displayOrder?: number;
}

export class CreateBusinessDto {
  @ApiProperty({ description: 'Name of the business', example: 'Blue Tokai Coffee Roasters' })
  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  @MaxLength(150)
  name!: string;

  @ApiProperty({ enum: BusinessCategory, description: 'Primary business category' })
  @IsEnum(BusinessCategory)
  category!: BusinessCategory;

  @ApiProperty({ description: 'Detailed description of the business' })
  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  @MaxLength(3000)
  description!: string;

  @ApiPropertyOptional({ description: 'Street/Public storefront address', example: '12th Main Road, HAL 2nd Stage' })
  @IsOptional()
  @IsString()
  @MaxLength(250)
  address?: string;

  @ApiPropertyOptional({ description: 'Locality name', example: 'Indiranagar' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  locality?: string;

  @ApiPropertyOptional({ description: 'City name', example: 'Bengaluru' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @ApiPropertyOptional({ description: 'State name', example: 'Karnataka' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  state?: string;

  @ApiPropertyOptional({ description: 'District name' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  district?: string;

  @ApiPropertyOptional({ description: 'Neighborhood / Sub-locality name' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  neighborhood?: string;

  @ApiPropertyOptional({ description: 'Country code', default: 'IN' })
  @IsOptional()
  @IsString()
  @MaxLength(5)
  countryCode?: string;

  @ApiPropertyOptional({ description: 'Public Storefront Latitude', example: 12.9784 })
  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiPropertyOptional({ description: 'Public Storefront Longitude', example: 77.6408 })
  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @ApiPropertyOptional({ description: 'Public Business Contact Phone (displayed publicly)', example: '+918012345678' })
  @IsOptional()
  @IsString()
  @MaxLength(25)
  contactPhone?: string;

  @ApiPropertyOptional({ description: 'Public Business Email', example: 'hello@bluetokai.com' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  contactEmail?: string;

  @ApiPropertyOptional({ description: 'Public Website or social page URL', example: 'https://bluetokaicoffee.com' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  website?: string;

  @ApiPropertyOptional({ description: 'IANA Timezone for operating hours', default: 'Asia/Kolkata' })
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
