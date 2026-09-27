import { ApiProperty } from '@nestjs/swagger';
import { IsUUID, IsNotEmpty } from 'class-validator';

export class CreateConversationDto {
  @ApiProperty({
    description: 'The target user UUID to start or retrieve a direct conversation with',
    example: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  })
  @IsUUID('4', { message: 'participantId must be a valid UUID' })
  @IsNotEmpty({ message: 'participantId is required' })
  participantId!: string;
}
