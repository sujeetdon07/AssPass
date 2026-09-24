import { IsEnum, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { BusinessStatus } from '../entities/business.entity.js';

export class UpdateBusinessStatusDto {
  @ApiProperty({
    enum: BusinessStatus,
    description: 'Updated lifecycle status of the business',
    example: BusinessStatus.ACTIVE,
  })
  @IsEnum(BusinessStatus)
  @IsNotEmpty()
  status!: BusinessStatus;
}
