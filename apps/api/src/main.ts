import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import compression from 'compression';
import { existsSync, mkdirSync } from 'fs';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';
import { join } from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  // rawBody is required to verify payment gateway webhook HMAC signatures.
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    rawBody: true,
    bufferLogs: true,
  });
  app.useLogger(app.get(Logger));
  // خلف nginx: عنوان المستخدم الحقيقي من X-Forwarded-For — بدونه يرى الخادم
  // كل المستخدمين بعنوان واحد فتتشارك حدود الطلبات (Throttler) بينهم جميعاً.
  app.set('trust proxy', 1);

  const mediaRoot = process.env.MEDIA_ROOT ?? join(process.cwd(), 'uploads');
  if (!existsSync(mediaRoot)) {
    mkdirSync(mediaRoot, { recursive: true });
  }
  // أسماء ملفات الوسائط UUID فريدة — تخزين دائم آمن يُسرّع إعادة التحميل
  // في المتصفح والتطبيق معاً بلا أي إعادة تنزيل.
  app.useStaticAssets(mediaRoot, {
    prefix: '/media/',
    setHeaders: (res) => {
      res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    },
  });

  app.use(
    helmet({
      // Swagger UI + media previews need relaxed CSP/COEP; API responses are JSON only.
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
      crossOriginEmbedderPolicy: false,
    }),
  );
  app.use(
    compression({
      filter: (req, res) => {
        if (req.headers.accept === 'text/event-stream') return false;
        return compression.filter(req, res);
      },
    }),
  );

  const corsOrigins = (process.env.CORS_ORIGINS ?? 'http://localhost:3001,http://localhost:3000,http://localhost:8080')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const localOrigin = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

  app.enableCors({
    origin: (origin, callback) => {
      if (!origin || corsOrigins.includes(origin) || localOrigin.test(origin)) {
        callback(null, true);
        return;
      }
      callback(null, false);
    },
    credentials: true,
  });

  app.setGlobalPrefix('api', { exclude: ['health'] });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  const swagger = new DocumentBuilder()
    .setTitle('VIBES API')
    .setDescription('Booking API for farms, wedding halls, and decoration services in Iraq')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('api/docs', app, SwaggerModule.createDocument(app, swagger));

  const port = Number(process.env.APP_PORT ?? 3000);
  await app.listen(port, '0.0.0.0');
}

bootstrap();
