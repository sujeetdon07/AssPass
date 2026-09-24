import {
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class CreateCommentDto {
  @ApiProperty({
    description: 'Comment text content (1 to 1000 characters).',
    example: 'Thanks for sharing! BESCOM confirmed the shutdown on their helpline as well.',
  })
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @IsNotEmpty({ message: 'Comment content cannot be empty.' })
  @MinLength(1, { message: 'Comment content must contain at least 1 character.' })
  @MaxLength(1000, { message: 'Comment content cannot exceed 1000 characters.' })
  content!: string;
}
