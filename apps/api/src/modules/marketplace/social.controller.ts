import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsArray, IsIn, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { SocialService } from './social.service';

class CreateCollectionDto {
  @IsString()
  @MaxLength(80)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  description?: string;

  @IsOptional()
  @IsIn(['PRIVATE', 'PUBLIC'])
  visibility?: 'PRIVATE' | 'PUBLIC';
}

class UpdateCollectionDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  description?: string;

  @IsOptional()
  @IsIn(['PRIVATE', 'PUBLIC'])
  visibility?: 'PRIVATE' | 'PUBLIC';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverUrl?: string;
}

class CollectionItemDto {
  @IsUUID()
  propertyId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  note?: string;
}

class CollectionItemNoteDto {
  @IsOptional()
  @IsString()
  @MaxLength(240)
  note?: string;
}

class CreatePostDto {
  @IsUUID()
  bookingId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  caption?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  mediaUrls?: string[];
}

class CommentDto {
  @IsString()
  @MaxLength(1000)
  body!: string;
}

class ReportDto {
  @IsOptional()
  @IsString()
  @MaxLength(400)
  reason?: string;
}

@ApiTags('social')
@ApiBearerAuth()
@Controller()
export class SocialController {
  constructor(private readonly social: SocialService) {}

  @Get('collections')
  collections(@CurrentUser() user: AuthUser) {
    return this.social.listCollections(user);
  }

  @Public()
  @Get('collections/public')
  publicCollections() {
    return this.social.listPublicCollections();
  }

  @Post('collections')
  createCollection(@CurrentUser() user: AuthUser, @Body() dto: CreateCollectionDto) {
    return this.social.createCollection(user, dto);
  }

  @Get('collections/:id')
  getCollection(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.social.getCollection(user, id);
  }

  @Patch('collections/:id')
  updateCollection(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateCollectionDto,
  ) {
    return this.social.updateCollection(user, id, dto);
  }

  @Delete('collections/:id')
  deleteCollection(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.social.deleteCollection(user, id);
  }

  @Post('collections/:id/items')
  addItem(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CollectionItemDto,
  ) {
    return this.social.addItem(user, id, dto.propertyId, dto.note);
  }

  @Patch('collections/:id/items/:propertyId')
  updateItemNote(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('propertyId') propertyId: string,
    @Body() dto: CollectionItemNoteDto,
  ) {
    return this.social.addItem(user, id, propertyId, dto.note);
  }

  @Delete('collections/:id/items/:propertyId')
  removeItem(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('propertyId') propertyId: string,
  ) {
    return this.social.removeItem(user, id, propertyId);
  }

  @Get('follows')
  following(@CurrentUser() user: AuthUser) {
    return this.social.listFollowing(user);
  }

  @Post('follows/:providerId')
  follow(@CurrentUser() user: AuthUser, @Param('providerId') providerId: string) {
    return this.social.follow(user, providerId);
  }

  @Delete('follows/:providerId')
  unfollow(@CurrentUser() user: AuthUser, @Param('providerId') providerId: string) {
    return this.social.unfollow(user, providerId);
  }

  @Public()
  @Get('follows/:providerId')
  followStatus(@CurrentUser() user: AuthUser | undefined, @Param('providerId') providerId: string) {
    return this.social.followStatus(user, providerId);
  }

  @Public()
  @Get('providers/:providerId/profile')
  providerProfile(@Param('providerId') providerId: string) {
    return this.social.providerProfile(providerId);
  }

  @Public()
  @Get('social/feed')
  publicFeed(@Query() query: { page?: string; pageSize?: string }) {
    return this.social.feed(undefined, query);
  }

  @Get('social/feed/following')
  followingFeed(
    @CurrentUser() user: AuthUser,
    @Query() query: { page?: string; pageSize?: string },
  ) {
    return this.social.feed(user, query);
  }

  @Post('social/posts')
  createPost(@CurrentUser() user: AuthUser, @Body() dto: CreatePostDto) {
    return this.social.createPost(user, dto);
  }

  @Throttle({ default: { limit: 40, ttl: 60_000 } })
  @Post('social/posts/:id/like')
  like(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.social.toggleLike(user, id);
  }

  @Get('social/posts/:id/comments')
  comments(@Param('id') id: string) {
    return this.social.listComments(id);
  }

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('social/posts/:id/comments')
  comment(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CommentDto,
  ) {
    return this.social.comment(user, id, dto.body);
  }

  @Post('social/posts/:id/report')
  report(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReportDto,
  ) {
    return this.social.report(user, id, dto.reason ?? '');
  }
}
