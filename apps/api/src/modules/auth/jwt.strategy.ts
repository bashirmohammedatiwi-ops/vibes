import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { CacheService } from '../../common/services/cache.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';

interface JwtPayload {
  sub: string;
  phone: string;
  role: AuthUser['role'];
}

export const userCacheKey = (id: string) => `cache:auth:user:${id}`;
const USER_CACHE_TTL_SECONDS = 60;

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('JWT_ACCESS_SECRET'),
    });
  }

  async validate(payload: JwtPayload): Promise<AuthUser> {
    // Every authenticated request hits this — cache briefly to avoid a DB
    // round-trip per request while still reacting to bans/role changes fast.
    const cached = await this.cache.get<{ id: string; phone: string; role: AuthUser['role']; isActive: boolean }>(
      userCacheKey(payload.sub),
    );

    const user =
      cached ?? (await this.prisma.user.findUnique({ where: { id: payload.sub } }));

    if (!user) {
      throw new UnauthorizedException();
    }
    if (!user.isActive) {
      throw new UnauthorizedException('الحساب معطّل');
    }

    if (!cached) {
      await this.cache.set(
        userCacheKey(user.id),
        { id: user.id, phone: user.phone, role: user.role, isActive: user.isActive },
        USER_CACHE_TTL_SECONDS,
      );
    }

    return { id: user.id, phone: user.phone, role: user.role };
  }
}
