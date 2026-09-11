import { Injectable } from '@nestjs/common';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CacheService } from '../../common/services/cache.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { shiftTimesFromMap } from '../../common/utils/shift.util';
import { PrismaService } from '../../prisma/prisma.service';

const PUBLIC_SETTINGS_CACHE_KEY = 'cache:settings:public';
const PUBLIC_SETTINGS_TTL_SECONDS = 60;

const KEYS = {
  supportPhone: 'supportPhone',
  paymentInstructions: 'paymentInstructions',
  morningShiftStart: 'morningShiftStart',
  morningShiftEnd: 'morningShiftEnd',
  eveningShiftStart: 'eveningShiftStart',
  eveningShiftEnd: 'eveningShiftEnd',
  fullShiftStart: 'fullShiftStart',
  fullShiftEnd: 'fullShiftEnd',
  commissionPercent: 'commissionPercent',
  cancellationPolicy: 'cancellationPolicy',
  minBookingNoticeDays: 'minBookingNoticeDays',
  zainCashEnabled: 'zainCashEnabled',
  qiCardEnabled: 'qiCardEnabled',
  manualProofEnabled: 'manualProofEnabled',
  maintenanceMode: 'maintenanceMode',
  maintenanceMessage: 'maintenanceMessage',
  notifyWhatsappEnabled: 'notify_whatsapp_enabled',
} as const;

export type SettingsPatch = {
  supportPhone?: string;
  paymentInstructions?: string;
  commissionPercent?: string;
  cancellationPolicy?: string;
  minBookingNoticeDays?: string;
  morningShiftStart?: string;
  morningShiftEnd?: string;
  eveningShiftStart?: string;
  eveningShiftEnd?: string;
  fullShiftStart?: string;
  fullShiftEnd?: string;
  zainCashEnabled?: boolean;
  qiCardEnabled?: boolean;
  manualProofEnabled?: boolean;
  maintenanceMode?: boolean;
  maintenanceMessage?: string;
  notifyWhatsappEnabled?: boolean;
};

function flag(value: string | undefined, fallback: boolean) {
  if (value === undefined || value === '') return fallback;
  return value === 'true';
}

@Injectable()
export class AdminSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityLogService,
    private readonly cache: CacheService,
  ) {}

  async get() {
    const map = await this.readMap();
    const shiftTimes = shiftTimesFromMap(map);
    const zainCashConfigured = !!process.env.ZAIN_CASH_MERCHANT_ID;
    const qiCardConfigured = !!process.env.QI_CARD_TERMINAL_ID;
    return {
      appName: 'VIBES',
      apiUrl: process.env.MEDIA_PUBLIC_URL?.replace('/media', '') ?? 'http://localhost:3000',
      publicWebUrl: process.env.PUBLIC_WEB_URL ?? 'https://vibes.iq',
      otpProvider: process.env.OTP_PROVIDER ?? 'development',
      mediaPublicUrl: process.env.MEDIA_PUBLIC_URL ?? 'http://localhost:3000/media',
      supportPhone: map[KEYS.supportPhone] || process.env.SUPPORT_PHONE || '9647700000000',
      paymentInstructions: map[KEYS.paymentInstructions] || '',
      commissionPercent: map[KEYS.commissionPercent] || '0',
      cancellationPolicy: map[KEYS.cancellationPolicy] || '',
      minBookingNoticeDays: map[KEYS.minBookingNoticeDays] || '1',
      ...shiftTimes,
      maintenanceMode: flag(map[KEYS.maintenanceMode], false),
      maintenanceMessage: map[KEYS.maintenanceMessage] || '',
      paymentGateways: {
        zainCash: flag(map[KEYS.zainCashEnabled], zainCashConfigured),
        qiCard: flag(map[KEYS.qiCardEnabled], qiCardConfigured),
        manualProof: flag(map[KEYS.manualProofEnabled], true),
      },
      paymentGatewaysConfigured: {
        zainCash: zainCashConfigured,
        qiCard: qiCardConfigured,
        manualProof: true,
      },
      features: {
        smsOtp: ['development', 'console', 'webhook', 'whatsapp'].includes(process.env.OTP_PROVIDER ?? 'development'),
        jobsQueue: true,
        globalSearch: true,
        farmShifts: true,
      },
      whatsappConfigured: !!(process.env.WHATSAPP_PHONE_NUMBER_ID && process.env.WHATSAPP_ACCESS_TOKEN),
      notifyWhatsappEnabled: flag(map[KEYS.notifyWhatsappEnabled], false),
    };
  }

  async public() {
    return this.cache.getOrSet(PUBLIC_SETTINGS_CACHE_KEY, PUBLIC_SETTINGS_TTL_SECONDS, async () => {
      const full = await this.get();
      return {
        appName: full.appName,
        supportPhone: full.supportPhone,
        paymentInstructions: full.paymentInstructions,
        cancellationPolicy: full.cancellationPolicy,
        minBookingNoticeDays: full.minBookingNoticeDays,
        maintenanceMode: full.maintenanceMode,
        maintenanceMessage: full.maintenanceMessage,
        paymentGateways: full.paymentGateways,
        morningShiftStart: full.morningShiftStart,
        morningShiftEnd: full.morningShiftEnd,
        eveningShiftStart: full.eveningShiftStart,
        eveningShiftEnd: full.eveningShiftEnd,
        fullShiftStart: full.fullShiftStart,
        fullShiftEnd: full.fullShiftEnd,
      };
    });
  }

  async update(user: AuthUser, patch: SettingsPatch) {
    if (patch.supportPhone !== undefined) {
      await this.upsert(KEYS.supportPhone, patch.supportPhone.trim());
    }
    if (patch.paymentInstructions !== undefined) {
      await this.upsert(KEYS.paymentInstructions, patch.paymentInstructions.trim());
    }
    if (patch.morningShiftStart !== undefined) {
      await this.upsert(KEYS.morningShiftStart, patch.morningShiftStart.trim());
    }
    if (patch.morningShiftEnd !== undefined) {
      await this.upsert(KEYS.morningShiftEnd, patch.morningShiftEnd.trim());
    }
    if (patch.eveningShiftStart !== undefined) {
      await this.upsert(KEYS.eveningShiftStart, patch.eveningShiftStart.trim());
    }
    if (patch.eveningShiftEnd !== undefined) {
      await this.upsert(KEYS.eveningShiftEnd, patch.eveningShiftEnd.trim());
    }
    if (patch.fullShiftStart !== undefined) {
      await this.upsert(KEYS.fullShiftStart, patch.fullShiftStart.trim());
    }
    if (patch.fullShiftEnd !== undefined) {
      await this.upsert(KEYS.fullShiftEnd, patch.fullShiftEnd.trim());
    }
    if (patch.commissionPercent !== undefined) {
      await this.upsert(KEYS.commissionPercent, patch.commissionPercent.trim());
    }
    if (patch.cancellationPolicy !== undefined) {
      await this.upsert(KEYS.cancellationPolicy, patch.cancellationPolicy.trim());
    }
    if (patch.minBookingNoticeDays !== undefined) {
      await this.upsert(KEYS.minBookingNoticeDays, patch.minBookingNoticeDays.trim());
    }
    if (patch.zainCashEnabled !== undefined) {
      await this.upsert(KEYS.zainCashEnabled, String(patch.zainCashEnabled));
    }
    if (patch.qiCardEnabled !== undefined) {
      await this.upsert(KEYS.qiCardEnabled, String(patch.qiCardEnabled));
    }
    if (patch.manualProofEnabled !== undefined) {
      await this.upsert(KEYS.manualProofEnabled, String(patch.manualProofEnabled));
    }
    if (patch.maintenanceMode !== undefined) {
      await this.upsert(KEYS.maintenanceMode, String(patch.maintenanceMode));
    }
    if (patch.maintenanceMessage !== undefined) {
      await this.upsert(KEYS.maintenanceMessage, patch.maintenanceMessage.trim());
    }
    if (patch.notifyWhatsappEnabled !== undefined) {
      await this.upsert(KEYS.notifyWhatsappEnabled, String(patch.notifyWhatsappEnabled));
    }
    await this.activity.log({
      userId: user.id,
      action: 'settings.update',
      entityType: 'settings',
      entityId: 'platform',
    });
    await this.cache.del(PUBLIC_SETTINGS_CACHE_KEY);
    return this.get();
  }

  private async readMap() {
    const rows = await this.prisma.platformSetting.findMany();
    return Object.fromEntries(rows.map((row) => [row.key, row.value])) as Record<string, string>;
  }

  private upsert(key: string, value: string) {
    return this.prisma.platformSetting.upsert({
      where: { key },
      update: { value },
      create: { key, value },
    });
  }
}
