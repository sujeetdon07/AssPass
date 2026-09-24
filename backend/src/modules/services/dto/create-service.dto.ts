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
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ServiceCategory } from '../entities/service-listing.entity.js';

export class CreateServiceDto {
  @ApiProperty({ description: 'Title or name of service', example: 'Expert Electrician & Wiring Repairs' })
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  @MaxLength(150)
  title!: string;

  @ApiProperty({ enum: ServiceCategory, description: 'Primary service category' })
  @IsEnum(ServiceCategory)
  category!: ServiceCategory;

  @ApiProperty({ description: 'Detailed description of services offered, expertise, and scope' })
  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  @MaxLength(3000)
  description!: string;

  @ApiPropertyOptional({ description: 'Primary locality served from', example: 'Indiranagar' })
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

  @ApiPropertyOptional({ description: 'Service radius in km from locality center', default: 10 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(50)
  serviceRadiusKm?: number;

  @ApiPropertyOptional({ description: 'Center Latitude for service area' })
  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiPropertyOptional({ description: 'Center Longitude for service area' })
  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @ApiPropertyOptional({ description: 'Public service contact phone (optional)', example: '+919876543210' })
  @IsOptional()
  @IsString()
  @MaxLength(25)
  contactPhone?: string;

  @ApiPropertyOptional({ description: 'Public service contact email (optional)' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  contactEmail?: string;

  @ApiPropertyOptional({ description: 'Years of professional experience', example: 7 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(70)
  experienceYears?: number;

  @ApiPropertyOptional({ description: 'Availability hours or schedule description', example: 'Mon–Sat: 8 AM – 8 PM' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  availability?: string;

  @ApiPropertyOptional({ description: 'Indicative starting price', example: 299.0 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  startingPrice?: number;
}
