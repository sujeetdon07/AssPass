import {
  IsNotEmpty,
  IsString,
  Matches,
  IsOptional,
  IsObject,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class DeviceMetadataDto {
  @ApiPropertyOptional({ example: 'Android 14' })
  @IsString()
  @IsOptional()
  platform?: string;

  @ApiPropertyOptional({ example: '1.0.0' })
  @IsString()
  @IsOptional()
  appVersion?: string;

  @ApiPropertyOptional({ example: 'Pixel 8' })
  @IsString()
  @IsOptional()
  model?: string;
}

export class VerifyOtpDto {
  @ApiProperty({
    example: '+919876543210',
    description: 'International phone number in E.164 format (or standard Indian 10 digits).',
  })
  @IsString()
  @IsNotEmpty({ message: 'Phone number is required.' })
  @Matches(/^(\+?[1-9]\d{6,14}|\d{10})$/, {
    message: 'Please enter a valid phone number.',
  })
  phoneNumber!: string;

  @ApiProperty({
    example: '123456',
    description: '6-digit verification code.',
  })
  @IsString()
  @IsNotEmpty({ message: 'Verification code is required.' })
  @Matches(/^\d{6}$/, { message: 'Verification code must be exactly 6 digits.' })
  otp!: string;

  @ApiPropertyOptional({ type: DeviceMetadataDto })
  @IsObject()
  @IsOptional()
  deviceMetadata?: DeviceMetadataDto;
}
