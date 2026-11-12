jest.mock('../src/models/User', () => ({}));
const service = require('../src/services/pushNotificationService');

describe('ringtone-aware push delivery', () => {
  const originalFetch = global.fetch;
  beforeEach(() => {
    service._recentPushDedupe = new Map();
    jest.spyOn(service, '_getServiceAccount').mockReturnValue({ project_id: 'test' });
    jest.spyOn(service, '_getGoogleAccessToken').mockResolvedValue('test-access');
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({}) });
  });
  afterEach(() => { jest.restoreAllMocks(); global.fetch = originalFetch; });

  test('Android uses data-only messages so saved local audio can play', async () => {
    await service.sendPushNotification({ token: 'test-android', platform: 'android', title: 'Order', message: 'New order', data: { type: 'new_order', orderId: '123' } });
    const payload = JSON.parse(global.fetch.mock.calls[0][1].body).message;
    expect(payload.notification).toBeUndefined();
    expect(payload.android.notification).toBeUndefined();
    expect(payload.android.priority).toBe('HIGH');
    expect(payload.data.title).toBe('Order');
    expect(payload.data.orderId).toBe('123');
  });

  test('iOS retains APNs alert delivery', async () => {
    await service.sendPushNotification({ token: 'test-ios', platform: 'ios', title: 'Alert', message: 'Hello' });
    const payload = JSON.parse(global.fetch.mock.calls[0][1].body).message;
    expect(payload.apns.payload.aps.alert.body).toBe('Hello');
    expect(payload.notification.title).toBe('Alert');
  });
});
