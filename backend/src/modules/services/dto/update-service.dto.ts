import {
  IsString,
  MaxLength,
  MinLength,
  IsEnum,
  IsOptional,
  IsNumber,
  Min,
  Max,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { ServiceCategory } from '../entities/service-listing.entity.js';

export class UpdateServiceDto {
  @ApiPropertyOptional({ description: 'Title or name of service' })
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(150)
  title?: string;

  @ApiPropertyOptional({ enum: ServiceCategory, description: 'Primary service category' })
  @IsOptional()
  @IsEnum(ServiceCategory)
  category?: ServiceCategory;

  @ApiPropertyOptional({ description: 'Detailed description of services offered' })
  @IsOptional()
  @IsString()
  @MinLength(10)
  @MaxLength(3000)
  description?: string;

  @ApiPropertyOptional({ description: 'Primary locality served from' })
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

  @ApiPropertyOptional({ description: 'Service radius in km from locality center' })
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

  @ApiPropertyOptional({ description: 'Public service contact phone' })
  @IsOptional()
  @IsString()
  @MaxLength(25)
  contactPhone?: string;

  @ApiPropertyOptional({ description: 'Public service contact email' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  contactEmail?: string;

  @ApiPropertyOptional({ description: 'Years of professional experience' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(70)
  experienceYears?: number;

  @ApiPropertyOptional({ description: 'Availability hours or schedule description' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  availability?: string;

  @ApiPropertyOptional({ description: 'Indicative starting price' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  startingPrice?: number;
}
