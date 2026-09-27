import { IsEnum, IsOptional } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { EventRsvpStatus } from '../entities/event-rsvp.entity.js';

export class RsvpEventDto {
  @ApiPropertyOptional({
    enum: EventRsvpStatus,
    description: 'RSVP status',
    default: EventRsvpStatus.GOING,
    example: EventRsvpStatus.GOING,
  })
  @IsOptional()
  @IsEnum(EventRsvpStatus, { message: 'Invalid RSVP status.' })
  status?: EventRsvpStatus = EventRsvpStatus.GOING;
}
