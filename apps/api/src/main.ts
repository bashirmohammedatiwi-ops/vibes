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

  const mediaRoot = process.env.MEDIA_ROOT ?? join(process.cwd(), 'uploads');
  if (!existsSync(mediaRoot)) {
    mkdirSync(mediaRoot, { recursive: true });
  }
  app.useStaticAssets(mediaRoot, { prefix: '/media/' });

  app.use(
    helmet({
      // Swagger UI + media previews need relaxed CSP/COEP; API responses are JSON only.
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
      crossOriginEmbedderPolicy: false,
    }),
  );
  app.use(compression());

  const corsOrigins = (process.env.CORS_ORIGINS ?? 'http://localhost:3001,http://localhost:3000,http://localhost:8080')
    .split(',')
    .map((origin) => origin.trim());

  app.enableCors({
    origin: corsOrigins,
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
