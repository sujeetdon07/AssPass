import { IsString, Length, IsOptional } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateProfileDto {
  @ApiPropertyOptional({
    example: 'sujeet_kumar',
    description: 'Unique public username (3 to 30 characters, letters, numbers, and underscores).',
  })
  @IsString()
  @IsOptional()
  @Length(3, 30, { message: 'Username must be between 3 and 30 characters.' })
  username?: string;

  @ApiPropertyOptional({
    example: 'Sujeet Sharma',
    description: 'User display name (2 to 50 characters).',
  })
  @IsString()
  @IsOptional()
  @Length(2, 50, { message: 'Display name must be between 2 and 50 characters.' })
  displayName?: string;

  @ApiPropertyOptional({
    example: 'Living in Sector 52 for 3 years. Passionate about urban gardening and morning runs.',
    description: 'Short bio or self-introduction (up to 300 characters).',
  })
  @IsString()
  @IsOptional()
  @Length(0, 300, { message: 'Bio cannot exceed 300 characters.' })
  bio?: string;

  @ApiPropertyOptional({
    example: 'https://api.dicebear.com/7.x/bottts/svg?seed=NoidaNeighbor',
    description: 'Avatar image URL or preset key.',
  })
  @IsString()
  @IsOptional()
  avatarUrl?: string;

  @ApiPropertyOptional({ example: 'IN', description: 'ISO 2-letter country code.' })
  @IsString()
  @IsOptional()
  countryCode?: string;

  @ApiPropertyOptional({ example: 'Uttar Pradesh' })
  @IsString()
  @IsOptional()
  state?: string;

  @ApiPropertyOptional({ example: 'Gautam Buddha Nagar' })
  @IsString()
  @IsOptional()
  district?: string;

  @ApiPropertyOptional({ example: 'Noida' })
  @IsString()
  @IsOptional()
  city?: string;

  @ApiPropertyOptional({ example: 'Sector 52' })
  @IsString()
  @IsOptional()
  locality?: string;

  @ApiPropertyOptional({ example: 'Antriksh Golf View, Tower B' })
  @IsString()
  @IsOptional()
  neighborhood?: string;
}
