import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches, MinLength } from 'class-validator';

export class PinLookupDto {
  @ApiProperty({ example: '9647700000003' })
  @IsString()
  @MinLength(10)
  @Matches(/^[0-9]+$/, { message: 'phone must contain digits only' })
  phone!: string;
}

export class PinAuthDto extends PinLookupDto {
  @ApiProperty({ example: '123456' })
  @IsString()
  @Matches(/^[0-9]{6}$/, { message: 'pin must be 6 digits' })
  pin!: string;
}
