import { IsNotEmpty, IsString, Length, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateUsernameDto {
  @ApiProperty({
    example: 'sujeet_kumar',
    description: 'Unique public username (3 to 30 characters, letters, numbers, and underscores).',
  })
  @IsString()
  @IsNotEmpty({ message: 'Username is required.' })
  @Length(3, 30, { message: 'Username must be between 3 and 30 characters.' })
  @Matches(/^[a-zA-Z0-9_@]+$/, {
    message: 'Username can only contain letters, numbers, and underscores.',
  })
  username!: string;
}
