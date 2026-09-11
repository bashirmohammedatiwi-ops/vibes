import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiExcludeEndpoint, ApiTags } from '@nestjs/swagger';
import type { RawBodyRequest } from '@nestjs/common';
import type { Request } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { GatewayProvider } from './payment-gateway.service';
import { PaymentsService } from './payments.service';

const PROVIDERS: GatewayProvider[] = ['zain-cash', 'qi-card'];

function assertProvider(value: string): GatewayProvider {
  if (!PROVIDERS.includes(value as GatewayProvider)) {
    throw new BadRequestException('بوابة دفع غير معروفة');
  }
  return value as GatewayProvider;
}

@ApiTags('payments')
@Controller('payments/callback')
export class PaymentCallbackController {
  constructor(private readonly payments: PaymentsService) {}

  @Public()
  @Post(':provider')
  handleWebhook(
    @Req() req: RawBodyRequest<Request>,
    @Param('provider') provider: string,
    @Body() payload: Record<string, unknown>,
    @Headers('x-signature') signature?: string,
  ) {
    return this.payments.handleCallback(assertProvider(provider), payload ?? {}, {
      rawBody: req.rawBody?.toString('utf8') ?? '',
      signature,
    });
  }

  /** Some gateways redirect the customer back with the result in the query string. */
  @Public()
  @Get(':provider')
  @ApiExcludeEndpoint()
  handleRedirect(
    @Param('provider') provider: string,
    @Query() query: Record<string, unknown>,
    @Headers('x-signature') signature?: string,
  ) {
    return this.payments.handleCallback(assertProvider(provider), query ?? {}, {
      rawBody: JSON.stringify(query ?? {}),
      signature,
    });
  }
}
