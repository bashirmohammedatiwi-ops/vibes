import { ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { isObservable, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!isPublic) return super.canActivate(context);

    const request = context.switchToHttp().getRequest<{ headers?: { authorization?: string } }>();
    const header = request.headers?.authorization;
    if (!header?.startsWith('Bearer ')) return true;

    try {
      const result = super.canActivate(context);
      if (isObservable(result)) {
        return result.pipe(catchError(() => of(true)));
      }
      if (result instanceof Promise) {
        return result.catch(() => true);
      }
      return result;
    } catch {
      return true;
    }
  }
}
