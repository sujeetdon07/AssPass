import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateNotificationPreferencesDto {
  @IsBoolean()
  @IsOptional()
  messagesEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  socialEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  communityEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  marketplaceEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  businessEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  systemEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  pushEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  emailEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  smsEnabled?: boolean;
}
