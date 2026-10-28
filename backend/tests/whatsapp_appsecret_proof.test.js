const crypto = require('crypto');
const whatsappService = require('../src/services/whatsappService');

describe('WhatsApp Meta Cloud API - appsecret_proof & Security Handling', () => {
  const sampleToken = 'EAAtestToken1234567890';
  const sampleSecret = 'f3b8c2d1e0a495867123456789abcdef';

  test('1. Generates accurate HMAC-SHA256 appsecret_proof', () => {
    const expected = crypto
      .createHmac('sha256', sampleSecret)
      .update(sampleToken)
      .digest('hex');

    const calculated = whatsappService.getAppSecretProof(sampleToken, sampleSecret);
    expect(calculated).toBe(expected);
    expect(calculated).toHaveLength(64); // 256 bits = 64 hex characters
  });

  test('2. Returns null when accessToken or appSecret is missing', () => {
    expect(whatsappService.getAppSecretProof('', sampleSecret)).toBeNull();
    expect(whatsappService.getAppSecretProof(sampleToken, '')).toBeNull();
    expect(whatsappService.getAppSecretProof('', '')).toBeNull();
  });

  test('3. buildGraphUrl appends appsecret_proof query parameter when secret is present', () => {
    const expectedProof = crypto
      .createHmac('sha256', sampleSecret)
      .update(sampleToken)
      .digest('hex');

    const url = whatsappService.buildGraphUrl('1284061438133660/messages', {
      accessToken: sampleToken,
      appSecret: sampleSecret,
    });

    const parsed = new URL(url);
    expect(parsed.pathname).toBe(`/${whatsappService.apiVersion}/1284061438133660/messages`);
    expect(parsed.searchParams.get('appsecret_proof')).toBe(expectedProof);
  });

  test('4. buildGraphUrl preserves existing query parameters and appends appsecret_proof', () => {
    const expectedProof = crypto
      .createHmac('sha256', sampleSecret)
      .update(sampleToken)
      .digest('hex');

    const url = whatsappService.buildGraphUrl('2525727467906581/message_templates', {
      accessToken: sampleToken,
      appSecret: sampleSecret,
      queryParams: { status: 'APPROVED', limit: 100 },
    });

    const parsed = new URL(url);
    expect(parsed.searchParams.get('status')).toBe('APPROVED');
    expect(parsed.searchParams.get('limit')).toBe('100');
    expect(parsed.searchParams.get('appsecret_proof')).toBe(expectedProof);
  });

  test('5. buildGraphUrl omits appsecret_proof if secret is not provided', () => {
    const url = whatsappService.buildGraphUrl('1284061438133660/messages', {
      accessToken: sampleToken,
      appSecret: '',
    });

    const parsed = new URL(url);
    expect(parsed.searchParams.has('appsecret_proof')).toBe(false);
  });

  test('6. formatMetaErrorMessage intercepts appsecret_proof error and returns actionable guidance', () => {
    const rawMetaError = {
      error: {
        message: 'API calls from the server require an appsecret_proof argument',
        type: 'GraphMethodException',
        code: 100,
        fbtrace_id: 'Az12345',
      },
    };

    const formatted = whatsappService.formatMetaErrorMessage(rawMetaError);
    expect(formatted).toContain("Meta Security Policy: 'appsecret_proof' is required");
    expect(formatted).toContain('WHATSAPP_APP_SECRET');
    expect(formatted).toContain('Require App Secret');
  });

  test('7. formatMetaErrorMessage leaves standard Meta errors intact', () => {
    const standardError = {
      error: {
        message: 'Message undeliverable',
        code: 131026,
      },
    };

    const formatted = whatsappService.formatMetaErrorMessage(standardError);
    expect(formatted).toBe('Message undeliverable');
  });
});
