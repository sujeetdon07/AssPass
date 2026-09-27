import { IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class CancelEventDto {
  @ApiPropertyOptional({
    description: 'Reason for cancelling the event',
    example: 'Venue under maintenance due to unforeseen rain.',
    maxLength: 500,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500, { message: 'Cancellation reason must not exceed 500 characters.' })
  reason?: string;
}
