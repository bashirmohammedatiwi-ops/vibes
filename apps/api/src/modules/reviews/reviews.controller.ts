import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsInt, IsString, IsUUID, Max, Min } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { ReviewsService } from './reviews.service';

class CreateReviewDto {
  @IsUUID()
  propertyId!: string;

  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsString()
  comment!: string;
}

@ApiTags('reviews')
@Controller()
export class ReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  @ApiBearerAuth()
  @Post('reviews')
  create(@CurrentUser() user: AuthUser, @Body() body: CreateReviewDto) {
    return this.reviews.upsert(user.id, body.propertyId, body.rating, body.comment);
  }

  @Public()
  @Get('properties/:id/reviews')
  list(@Param('id') propertyId: string) {
    return this.reviews.list(propertyId);
  }
}
