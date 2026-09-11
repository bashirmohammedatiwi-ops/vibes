import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, Length, Matches, MinLength } from 'class-validator';

export class VerifyOtpDto {
  @ApiProperty({ example: '9647700000000' })
  @IsString()
  @MinLength(10)
  @Matches(/^[0-9]+$/)
  phone!: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(4, 8)
  code!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  name?: string;
}
