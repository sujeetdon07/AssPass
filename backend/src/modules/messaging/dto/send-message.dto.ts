import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, MaxLength, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';

export class SendMessageDto {
  @ApiProperty({
    description: 'Unique client-generated idempotency identifier for duplicate message protection',
    example: 'msg_client_1727600000_abc123',
    maxLength: 100,
  })
  @IsString()
  @IsNotEmpty({ message: 'clientMessageId is required' })
  @MaxLength(100, { message: 'clientMessageId must not exceed 100 characters' })
  clientMessageId!: string;

  @ApiProperty({
    description: 'Text content of the direct message (plain text)',
    example: 'Hello! Is this item still available?',
    minLength: 1,
    maxLength: 2000,
  })
  @IsString()
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @IsNotEmpty({ message: 'Message content cannot be empty' })
  @MinLength(1, { message: 'Message content cannot be empty' })
  @MaxLength(2000, { message: 'Message content cannot exceed 2000 characters' })
  content!: string;
}
