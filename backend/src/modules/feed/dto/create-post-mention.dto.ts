import { IsInt, IsNotEmpty, IsUUID, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreatePostMentionDto {
  @ApiProperty({
    description: 'Immutable User UUID of the mentioned user.',
    example: '8d7f2d4e-8b2d-4cf8-9f51-1a2b3c4d5e6f',
  })
  @IsUUID('all', { message: 'userId must be a valid UUID.' })
  @IsNotEmpty({ message: 'userId cannot be empty.' })
  userId!: string;

  @ApiProperty({
    description: 'UTF-16 code-unit starting offset of the mention in content.',
    example: 4,
    minimum: 0,
  })
  @IsInt({ message: 'start offset must be an integer.' })
  @Min(0, { message: 'start offset cannot be negative.' })
  start!: number;

  @ApiProperty({
    description: 'UTF-16 code-unit length of the mention token (e.g. 7 for @sujeet).',
    example: 7,
    minimum: 1,
  })
  @IsInt({ message: 'length must be an integer.' })
  @Min(1, { message: 'length must be at least 1.' })
  length!: number;
}
