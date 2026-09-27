import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import { createHash, randomUUID } from 'node:crypto';
import ms from 'ms';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { JobsService } from '../../jobs/jobs.service';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { PinAuthDto } from './dto/pin-auth.dto';
import { hashPin, verifyPin } from './pin-hash';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';

interface RequestMeta {
  ip?: string;
  userAgent?: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly jobs: JobsService,
    private readonly activity: ActivityLogService,
  ) {}

  async sendOtp(dto: SendOtpDto) {
    const provider = this.config.get<string>('OTP_PROVIDER', 'development');
    const code =
      provider === 'development'
        ? this.config.get<string>('ADMIN_OTP', '123456')
        : this.randomOtp();

    const ttl = this.config.get<number>('OTP_EXPIRES_IN_SECONDS', 300);
    await this.redis.set(`otp:${dto.phone}`, code, 'EX', ttl);

    if (provider === 'development') {
      return { sent: true, expiresIn: ttl, provider, debugOtp: code };
    }

    // Dispatched on the BullMQ queue (retried on failure) so the request
    // doesn't block on the SMS gateway's round-trip.
    await this.jobs.enqueue('send-otp-sms', { phone: dto.phone, code });
    return { sent: true, expiresIn: ttl, provider, queued: true };
  }

  async verifyOtp(dto: VerifyOtpDto, meta: RequestMeta = {}) {
    const stored = await this.redis.get(`otp:${dto.phone}`);
    const provider = this.config.get<string>('OTP_PROVIDER', 'development');
    const devOtp = this.config.get<string>('ADMIN_OTP', '123456');
    const valid = stored === dto.code || (provider === 'development' && dto.code === devOtp);

    if (!valid) {
      throw new UnauthorizedException('رمز التحقق غير صحيح');
    }

    await this.redis.del(`otp:${dto.phone}`);

    const user = await this.prisma.user.upsert({
      where: { phone: dto.phone },
      update: dto.name ? { name: dto.name } : {},
      create: {
        phone: dto.phone,
        name: dto.name,
        role: UserRole.CUSTOMER,
      },
    });

    if (!user.isActive) {
      throw new UnauthorizedException('الحساب معطّل');
    }

    await this.activity.log({
      userId: user.id,
      action: 'auth.login',
      entityType: 'user',
      entityId: user.id,
      metadata: { ip: meta.ip, userAgent: meta.userAgent },
    });

    return this.issueTokens(user.id, user.phone, user.role, user.name, meta);
  }

  /** هل لهذا الرقم رقم سري محفوظ؟ الحساب غير الموجود يُعامل كزائر جديد. */
  async lookupPin(phone: string) {
    const user = await this.prisma.user.findUnique({
      where: { phone },
      select: { pinHash: true, isActive: true },
    });
    if (user && !user.isActive) {
      throw new UnauthorizedException('الحساب معطّل');
    }
    return { hasPin: Boolean(user?.pinHash) };
  }

  /**
   * دخول برقم سري من ستة أرقام.
   * أول استخدام لحساب بلا رقم سري يثبّت الرقم، والمحاولات التالية تتحقق منه.
   */
  async loginWithPin(dto: PinAuthDto, meta: RequestMeta = {}) {
    const failKey = `pin:fail:${dto.phone}`;
    const fails = Number((await this.redis.get(failKey)) ?? 0);
    if (fails >= 8) {
      throw new UnauthorizedException('محاولات كثيرة — انتظر قليلاً ثم أعد المحاولة');
    }

    const existing = await this.prisma.user.findUnique({ where: { phone: dto.phone } });
    if (existing && !existing.isActive) {
      throw new UnauthorizedException('الحساب معطّل');
    }

    let user = existing;
    if (!existing?.pinHash) {
      const pinHash = hashPin(dto.pin);
      user = await this.prisma.user.upsert({
        where: { phone: dto.phone },
        update: { pinHash },
        create: {
          phone: dto.phone,
          role: UserRole.CUSTOMER,
          pinHash,
        },
      });
    } else if (!verifyPin(dto.pin, existing.pinHash)) {
      await this.redis.set(failKey, String(fails + 1), 'EX', 15 * 60);
      throw new UnauthorizedException('الرقم السري غير صحيح');
    } else {
      await this.redis.del(failKey);
    }

    if (!user) {
      throw new UnauthorizedException('تعذر الدخول');
    }

    await this.activity.log({
      userId: user.id,
      action: 'auth.login',
      entityType: 'user',
      entityId: user.id,
      metadata: { ip: meta.ip, userAgent: meta.userAgent, method: 'pin' },
    });

    return this.issueTokens(user.id, user.phone, user.role, user.name, meta);
  }

  async refresh(refreshToken: string, meta: RequestMeta = {}) {
    let payload: { sub: string };
    try {
      payload = await this.jwt.verifyAsync<{ sub: string }>(refreshToken, {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('رمز التحديث غير صالح');
    }

    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({ where: { tokenHash } });
    if (!stored || stored.revokedAt || stored.expiresAt < new Date() || stored.userId !== payload.sub) {
      throw new UnauthorizedException('رمز التحديث غير صالح أو تم إلغاؤه');
    }

    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException();
    }

    // Rotate: revoke the used refresh token so it can't be replayed.
    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });

    return this.issueTokens(user.id, user.phone, user.role, user.name, meta);
  }

  /** Revokes one session (or the given token if it belongs to the user). */
  async logout(userId: string, refreshToken?: string) {
    if (refreshToken) {
      const tokenHash = this.hashToken(refreshToken);
      await this.prisma.refreshToken.updateMany({
        where: { tokenHash, userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    await this.activity.log({ userId, action: 'auth.logout', entityType: 'user', entityId: userId });
    return { loggedOut: true };
  }

  /** Revokes every active session for the user (e.g. "sign out everywhere"). */
  async logoutAll(userId: string) {
    const { count } = await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    await this.activity.log({
      userId,
      action: 'auth.logout_all',
      entityType: 'user',
      entityId: userId,
      metadata: { revoked: count },
    });
    return { loggedOut: true, revokedSessions: count };
  }

  async listSessions(userId: string) {
    const sessions = await this.prisma.refreshToken.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
      select: { id: true, userAgent: true, ip: true, createdAt: true, expiresAt: true },
    });
    return sessions;
  }

  private async issueTokens(
    id: string,
    phone: string,
    role: UserRole,
    name: string | null,
    meta: RequestMeta = {},
  ) {
    const payload = { sub: id, phone, role, jti: randomUUID() };
    const refreshExpiresIn = this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '30d');
    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(payload, {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        expiresIn: this.config.get<string>('JWT_ACCESS_EXPIRES_IN', '15m'),
      }),
      this.jwt.signAsync(
        { sub: id, jti: randomUUID() },
        {
          secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
          expiresIn: refreshExpiresIn,
        },
      ),
    ]);

    await this.prisma.refreshToken.create({
      data: {
        userId: id,
        tokenHash: this.hashToken(refreshToken),
        userAgent: meta.userAgent?.slice(0, 255),
        ip: meta.ip,
        expiresAt: new Date(Date.now() + ms(refreshExpiresIn as ms.StringValue)),
      },
    });

    return {
      accessToken,
      refreshToken,
      user: { id, phone, role, name },
    };
  }

  private hashToken(token: string) {
    return createHash('sha256').update(token).digest('hex');
  }

  private randomOtp() {
    const length = this.config.get<number>('OTP_LENGTH', 6);
    const max = 10 ** length;
    return Math.floor(Math.random() * max)
      .toString()
      .padStart(length, '0');
  }
}
