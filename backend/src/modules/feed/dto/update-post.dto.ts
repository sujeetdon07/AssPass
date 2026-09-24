import {
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class UpdatePostDto {
  @ApiProperty({
    description: 'Updated post text content (1 to 5000 characters).',
    example: 'Updated notice: Power cut postponed to Friday.',
  })
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @IsNotEmpty({ message: 'Post content cannot be empty.' })
  @MinLength(1, { message: 'Post content must contain at least 1 character.' })
  @MaxLength(5000, { message: 'Post content cannot exceed 5000 characters.' })
  content!: string;
}
