import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches, MinLength } from 'class-validator';

export class SendOtpDto {
  @ApiProperty({ example: '9647700000000' })
  @IsString()
  @MinLength(10)
  @Matches(/^[0-9]+$/, { message: 'phone must contain digits only' })
  phone!: string;
}
