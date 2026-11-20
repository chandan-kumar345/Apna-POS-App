describe('WhatsApp customer OTP sender', () => {
  let originalFetch, originalToken;
  beforeEach(() => {
    jest.resetModules();
    originalFetch = global.fetch;
    originalToken = process.env.STOREFRONT_OTP_ACCESS_TOKEN;
    process.env.STOREFRONT_OTP_ACCESS_TOKEN = 'unit-test-only-token';
  });
  afterEach(() => {
    global.fetch = originalFetch;
    if (originalToken == null) delete process.env.STOREFRONT_OTP_ACCESS_TOKEN;
    else process.env.STOREFRONT_OTP_ACCESS_TOKEN = originalToken;
  });
  function fake({ validSender = true, category = 'AUTHENTICATION', delivered = true } = {}) {
    global.fetch = jest.fn(async (url, options) => ({
      ok: options.method !== 'POST' || delivered,
      json: async () => options.method === 'POST' ? (delivered ? { messages: [{ id: 'test-message' }] } : { error: { code: 100 } })
        : url.includes('/phone_numbers') ? { data: [{ id: validSender ? '1284061438133660' : 'different-sender' }] }
        : { data: [{ name: 'apna_pos_auth_otp', category, status: 'APPROVED', language: 'en' }] },
    }));
  }
  test('uses the exact WABA, sender and approved English authentication template', async () => {
    fake();
    const result = await require('../src/services/storefrontOtpTransport').send('9876543210', '654321');
    expect(result.messageId).toBe('test-message');
    expect(global.fetch.mock.calls[0][0]).toContain('/2525727467906581/phone_numbers');
    const [url, request] = global.fetch.mock.calls.at(-1);
    expect(url).toMatch(/\/1284061438133660\/messages$/);
    const body = JSON.parse(request.body);
    expect(body).toMatchObject({ to: '919876543210', type: 'template', template: { name: 'apna_pos_auth_otp', language: { code: 'en' } } });
    expect(body.template.components[0].parameters[0].text).toBe('654321');
    expect(body.template.components[1].parameters[0].text).toBe('654321');
  });
  test.each([{ validSender: false }, { category: 'UTILITY' }])('rejects invalid sender/template without sending a code', async options => {
    fake(options);
    await expect(require('../src/services/storefrontOtpTransport').send('9876543210', '654321')).rejects.toMatchObject({ statusCode: 503 });
    expect(global.fetch.mock.calls.some(([, options]) => options.method === 'POST')).toBe(false);
  });
  test('provider rejection never falls back to text or simulated success', async () => {
    fake({ delivered: false });
    await expect(require('../src/services/storefrontOtpTransport').send('9876543210', '654321')).rejects.toMatchObject({ statusCode: 503 });
    expect(global.fetch.mock.calls.filter(([, options]) => options.method === 'POST')).toHaveLength(1);
  });
});
