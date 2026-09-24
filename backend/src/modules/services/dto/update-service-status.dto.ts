import { IsEnum, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { ServiceStatus } from '../entities/service-listing.entity.js';

export class UpdateServiceStatusDto {
  @ApiProperty({
    enum: ServiceStatus,
    description: 'Updated lifecycle status of the service listing',
    example: ServiceStatus.ACTIVE,
  })
  @IsEnum(ServiceStatus)
  @IsNotEmpty()
  status!: ServiceStatus;
}
