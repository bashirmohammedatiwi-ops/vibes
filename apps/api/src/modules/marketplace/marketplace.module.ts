import { Module } from '@nestjs/common';
import { PaginationService } from '../../common/services/query-helpers';
import { CommerceController } from './commerce.controller';
import { CommerceService } from './commerce.service';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { MarketplaceLifecycleService } from './marketplace-lifecycle.service';
import { ChatEventsService } from './chat-events.service';
import { CallsController } from './calls.controller';
import { CallQueueService } from './call-queue.service';
import { CallsService } from './calls.service';
import { SocialController } from './social.controller';
import { SocialService } from './social.service';
import { UserNotificationsController } from './user-notifications.controller';
import { UserNotificationsService } from './user-notifications.service';

@Module({
  controllers: [
    ConversationsController,
    CallsController,
    CommerceController,
    SocialController,
    UserNotificationsController,
  ],
  providers: [
    PaginationService,
    MarketplaceLifecycleService,
    ChatEventsService,
    CallQueueService,
    CallsService,
    ConversationsService,
    CommerceService,
    SocialService,
    UserNotificationsService,
  ],
  exports: [MarketplaceLifecycleService, ConversationsService, CommerceService, CallsService, CallQueueService],
})
export class MarketplaceModule {}
