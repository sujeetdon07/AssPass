import { IsNotEmpty, IsString, Length, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CompleteOnboardingDto {
  @ApiPropertyOptional({
    example: 'sujeet_kumar',
    description: 'Optional unique public username (3 to 30 characters).',
  })
  @IsString()
  @IsOptional()
  @Length(3, 30, { message: 'Username must be between 3 and 30 characters.' })
  username?: string;

  @ApiProperty({
    example: 'Sujeet Sharma',
    description: 'User display name (2 to 50 characters).',
  })
  @IsString()
  @IsNotEmpty({ message: 'Display name is required.' })
  @Length(2, 50, { message: 'Display name must be between 2 and 50 characters.' })
  displayName!: string;

  @ApiPropertyOptional({ example: 'IN', description: 'ISO 2-letter country code.' })
  @IsString()
  @IsOptional()
  countryCode?: string;

  @ApiPropertyOptional({ example: 'Uttar Pradesh' })
  @IsString()
  @IsOptional()
  state?: string;

  @ApiPropertyOptional({ example: 'Meerut' })
  @IsString()
  @IsOptional()
  district?: string;

  @ApiPropertyOptional({ example: 'Meerut' })
  @IsString()
  @IsOptional()
  city?: string;

  @ApiPropertyOptional({ example: 'Shastri Nagar' })
  @IsString()
  @IsOptional()
  locality?: string;

  @ApiPropertyOptional({ example: 'Pocket B' })
  @IsString()
  @IsOptional()
  neighborhood?: string;

  @ApiPropertyOptional({ example: 'https://example.com/avatar.jpg' })
  @IsString()
  @IsOptional()
  avatarUrl?: string;
}
