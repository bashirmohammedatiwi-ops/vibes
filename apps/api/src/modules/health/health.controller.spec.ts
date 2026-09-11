import { HealthController } from './health.controller';

describe('HealthController', () => {
  it('returns ok when dependencies respond', async () => {
    const controller = new HealthController(
      { $queryRaw: async () => [1] } as never,
      { ping: async () => 'PONG' } as never,
    );

    const result = await controller.health();
    expect(result.status).toBe('ok');
    expect(result.database).toBe('up');
    expect(result.redis).toBe('up');
  });
});
