import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { CallsService } from '../modules/marketplace/calls.service';

/**
 * يراقب مكالمات الرنين المعلّقة — ما لم يُجب خلال مهلة الخادم
 * تُسجَّل فائتة ويصل الطرفان إشعار النهاية عبر قناة المحادثة.
 */
@Injectable()
export class CallLifecycleService {
  private readonly logger = new Logger(CallLifecycleService.name);

  constructor(private readonly calls: CallsService) {}

  @Cron(CronExpression.EVERY_30_SECONDS)
  async expireRingingCalls() {
    try {
      const expired = await this.calls.expireStaleRinging();
      if (expired > 0) {
        this.logger.log(`انتهت مهلة ${expired} مكالمة رنين`);
      }
    } catch (error) {
      this.logger.warn(`فشل تنظيف مكالمات الرنين: ${String(error)}`);
    }
  }
}
