import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { DevicePlatform } from '../entities/device-token.entity.js';

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  token!: string;

  @IsEnum(DevicePlatform)
  @IsOptional()
  platform?: DevicePlatform = DevicePlatform.ANDROID;

  @IsString()
  @IsOptional()
  deviceId?: string;
}
