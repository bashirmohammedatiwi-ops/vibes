import { Throttle, SkipThrottle } from '@nestjs/throttler';
import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Header,
  Param,
  Patch,
  Post,
  Query,
  Sse,
  UploadedFile,
  UseInterceptors,
  MessageEvent,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { diskStorage } from 'multer';
import { existsSync, mkdirSync } from 'fs';
import { extname, join } from 'path';
import { randomUUID } from 'node:crypto';
import { interval, map, merge, Observable } from 'rxjs';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { ConversationsService } from './conversations.service';
import { ChatEventsService } from './chat-events.service';

class SendMessageDto {
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  body?: string;

  @IsOptional()
  @IsString()
  imageUrl?: string;
}

class OpenBookingDto {
  @IsString()
  bookingId!: string;
}

class OpenPropertyDto {
  @IsString()
  propertyId!: string;
}

function messageStorage() {
  return diskStorage({
    destination: (_req, _file, cb) => {
      const root = join(process.env.MEDIA_ROOT ?? './uploads', 'messages');
      if (!existsSync(root)) mkdirSync(root, { recursive: true });
      cb(null, root);
    },
    filename: (_req, file, cb) => {
      cb(null, `${randomUUID()}${extname(file.originalname)}`);
    },
  });
}

@ApiTags('conversations')
@ApiBearerAuth()
@Controller('conversations')
export class ConversationsController {
  constructor(
    private readonly conversations: ConversationsService,
    private readonly events: ChatEventsService,
  ) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.conversations.list(user);
  }

  @Get('unread')
  unread(@CurrentUser() user: AuthUser) {
    return this.conversations.unreadCount(user);
  }

  @Patch('read')
  readAll(@CurrentUser() user: AuthUser) {
    return this.conversations.markAllRead(user);
  }

  @Post('support')
  support(@CurrentUser() user: AuthUser) {
    return this.conversations.openSupport(user);
  }

  @Post('booking')
  openBooking(@CurrentUser() user: AuthUser, @Body() dto: OpenBookingDto) {
    return this.conversations.openForBooking(user, dto.bookingId);
  }

  @Post('property')
  openProperty(@CurrentUser() user: AuthUser, @Body() dto: OpenPropertyDto) {
    return this.conversations.openForProperty(user, dto.propertyId);
  }

  @Get(':id')
  getOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.conversations.getOne(user, id);
  }

  @Get(':id/messages')
  messages(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query() query: { before?: string; after?: string; pageSize?: string },
  ) {
    return this.conversations.messages(user, id, query);
  }

  @SkipThrottle()
  @Sse(':id/stream')
  @Header('Cache-Control', 'no-cache')
  @Header('X-Accel-Buffering', 'no')
  async stream(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<Observable<MessageEvent>> {
    await this.conversations.ensureAccess(user, id);
    return merge(
      interval(15_000).pipe(map(() => ({ data: { type: 'ping' } }))),
      this.events.stream(id).pipe(map((data) => ({ data: (data ?? {}) as object }))),
    );
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post(':id/messages')
  send(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.conversations.send(user, id, dto);
  }

  @Throttle({ default: { limit: 15, ttl: 60_000 } })
  @Post(':id/messages/image')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: messageStorage(),
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        const ok = /^image\/(jpeg|png|webp|gif)$/.test(file.mimetype);
        cb(ok ? null : new BadRequestException('صيغة الصورة غير مدعومة'), ok);
      },
    }),
  )
  sendImage(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @UploadedFile() file?: Express.Multer.File,
    @Body() body?: { body?: string },
  ) {
    const base = (process.env.MEDIA_PUBLIC_URL ?? 'http://localhost:3000/media').replace(/\/$/, '');
    const imageUrl = file ? `${base}/messages/${file.filename}` : undefined;
    return this.conversations.send(user, id, { body: body?.body, imageUrl });
  }
}
