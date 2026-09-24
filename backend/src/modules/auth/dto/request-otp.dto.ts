import { IsNotEmpty, IsString, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RequestOtpDto {
  @ApiProperty({
    example: '+919876543210',
    description: 'International phone number in E.164 format (or standard Indian 10 digits).',
  })
  @IsString()
  @IsNotEmpty({ message: 'Phone number is required.' })
  @Matches(/^(\+?[1-9]\d{6,14}|\d{10})$/, {
    message: 'Please enter a valid phone number (e.g. +919876543210 or 9876543210).',
  })
  phoneNumber!: string;
}
