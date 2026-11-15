const PushService = require('../src/services/pushNotificationService').constructor;

describe('Incoming order transport contract', () => {
  let service;
  beforeEach(() => {
    service = new PushService();
    jest.spyOn(service, '_getServiceAccount').mockReturnValue({ project_id: 'test-project' });
    jest.spyOn(service, '_getGoogleAccessToken').mockResolvedValue('test-oauth-token');
    global.fetch = jest.fn(async () => ({ ok: true, status: 200, json: async () => ({ name: 'test-message' }) }));
    jest.spyOn(console, 'log').mockImplementation(() => {});
  });
  afterEach(() => { jest.restoreAllMocks(); });

  async function send(platform = 'android', data = {}) {
    await service.sendPushNotification({ token: 'test-device-token', platform,
      title: 'New table order', message: 'Table 2', data: {
        type: 'whatsapp_order_request', orderId: 'order-2', orderNumber: 'ORD-2',
        orderSource: 'storefront', tableNumber: 'T02', items: [{ name: 'Pizza', quantity: 1 }], ...data,
      } });
    expect(fetch).toHaveBeenCalledTimes(1);
    return JSON.parse(fetch.mock.calls[0][1].body).message;
  }

  test('Android order executes the native handler and survives a brief offline interval', async () => {
    const payload = await send();
    expect(payload.notification).toBeUndefined();
    expect(payload.android.notification).toBeUndefined();
    expect(payload.android.priority).toBe('HIGH');
    expect(payload.android.ttl).toBe('90s');
    expect(payload.android.collapse_key).toBe('order_order-2');
    expect(payload.data.tableNumber).toBe('T02');
    expect(payload.data.orderId).toBe('order-2');
    expect(JSON.parse(payload.data.items)).toEqual([{ name: 'Pizza', quantity: 1 }]);
    expect(Object.values(payload.data).every(value => typeof value === 'string')).toBe(true);
  });

  test('legacy fallback retains the same bounded Android order contract', async () => {
    service._getServiceAccount.mockReturnValue(null);
    const previousKey = process.env.FCM_SERVER_KEY;
    process.env.FCM_SERVER_KEY = 'test-server-key';
    fetch.mockResolvedValue({ ok: true, status: 200, json: async () => ({ success: 1 }) });
    try {
      await service.sendPushNotification({ token: 'test-device-token', platform: 'android',
        title: 'Order', message: 'Review order', data: { type: 'new_order', orderId: 'order-3' } });
      const payload = JSON.parse(fetch.mock.calls[0][1].body);
      expect(payload.notification).toBeUndefined();
      expect(payload.android.notification).toBeUndefined();
      expect(payload.time_to_live).toBe(90);
      expect(payload.android.ttl).toBe('90s');
    } finally {
      if (previousKey === undefined) delete process.env.FCM_SERVER_KEY;
      else process.env.FCM_SERVER_KEY = previousKey;
    }
  });

  test('iOS retains alert presentation and its existing transport settings', async () => {
    const payload = await send('ios');
    expect(payload.notification).toEqual({ title: 'New table order', body: 'Table 2' });
    expect(payload.apns.headers['apns-push-type']).toBe('alert');
    expect(payload.android.ttl).toBe('0s');
  });

  test('ordinary Android notifications keep the existing data-only path and TTL', async () => {
    await service.sendPushNotification({ token: 'test-device-token', platform: 'android',
      title: 'Daily report', message: 'Report ready', data: { type: 'daily_sales_summary' } });
    const payload = JSON.parse(fetch.mock.calls[0][1].body).message;
    expect(payload.notification).toBeUndefined();
    expect(payload.android.notification).toBeUndefined();
    expect(payload.android.ttl).toBe('0s');
    expect(payload.android.collapse_key).toBe('daily_sales_summary');
  });
});
