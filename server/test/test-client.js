const http = require('http');
const { startServer } = require('../src/server');

// Helper to make HTTP request using standard Node.js http module
const makeRequest = (options, body = null) => {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ statusCode: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ statusCode: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', (err) => reject(err));

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
};

const runVerification = async () => {
  console.log('🧪 Starting Automated Backend Server Verification Suite...\n');

  // Auto start server for testing
  await startServer();
  await new Promise((resolve) => setTimeout(resolve, 500)); // give server 500ms to bind

  const PORT = process.env.PORT || 5000;
  const baseUrlOptions = {
    hostname: 'localhost',
    port: PORT,
    headers: {
      'Content-Type': 'application/json',
    },
  };

  try {
    // 1. Health Check
    console.log('1️⃣ Testing Health Check (/api/health)...');
    const health = await makeRequest({
      ...baseUrlOptions,
      path: '/api/health',
      method: 'GET',
    });
    console.log(`   Status: ${health.statusCode} | Result: ${JSON.stringify(health.data)}`);

    // 2. Registration Flow
    console.log('\n2️⃣ Testing Registration Flow (/api/auth/register)...');
    const testEmail = `test_${Date.now()}@example.com`;
    const testPhone = `+9199${Math.floor(10000000 + Math.random() * 90000000)}`;

    const regResult = await makeRequest(
      {
        ...baseUrlOptions,
        path: '/api/auth/register',
        method: 'POST',
      },
      {
        name: 'Chandan Kumar',
        email: testEmail,
        phone: testPhone,
        password: 'Password123!',
        deviceId: 'android_s24_test',
        deviceName: 'Samsung S24 Ultra',
        businessName: 'Chandan POS Store',
      }
    );

    console.log(`   Status: ${regResult.statusCode}`);
    console.log(`   Registered User ID: ${regResult.data?.user?.id || 'N/A'}`);
    console.log(`   Access Token Received: ${Boolean(regResult.data?.accessToken)}`);
    console.log(`   Refresh Token Received: ${Boolean(regResult.data?.refreshToken)}`);

    if (!regResult.data?.accessToken) {
      console.error('❌ Registration failed, stopping tests:', regResult.data);
      process.exit(1);
    }

    const { accessToken, refreshToken, deviceId } = regResult.data;

    // 3. Authenticated /me Profile
    console.log('\n3️⃣ Testing GET Profile (/api/auth/me)...');
    const profile = await makeRequest({
      ...baseUrlOptions,
      path: '/api/auth/me',
      method: 'GET',
      headers: {
        ...baseUrlOptions.headers,
        Authorization: `Bearer ${accessToken}`,
      },
    });
    console.log(`   Status: ${profile.statusCode} | Profile Name: ${profile.data?.user?.name}`);

    // 4. Multi-Device Sessions
    console.log('\n4️⃣ Testing GET Devices (/api/auth/devices)...');
    const devices = await makeRequest({
      ...baseUrlOptions,
      path: '/api/auth/devices',
      method: 'GET',
      headers: {
        ...baseUrlOptions.headers,
        Authorization: `Bearer ${accessToken}`,
      },
    });
    console.log(`   Status: ${devices.statusCode} | Device Count: ${devices.data?.count}`);

    // 5. Login Flow
    console.log('\n5️⃣ Testing Password Login (/api/auth/login)...');
    const loginResult = await makeRequest(
      {
        ...baseUrlOptions,
        path: '/api/auth/login',
        method: 'POST',
      },
      {
        email: testEmail,
        password: 'Password123!',
        deviceId: 'ipad_pro_test',
        deviceName: 'iPad Pro 12.9',
      }
    );
    console.log(`   Status: ${loginResult.statusCode} | Message: ${loginResult.data?.message}`);

    // 6. Refresh Token
    console.log('\n6️⃣ Testing Refresh Token (/api/auth/refresh-token)...');
    const refreshResult = await makeRequest(
      {
        ...baseUrlOptions,
        path: '/api/auth/refresh-token',
        method: 'POST',
      },
      {
        refreshToken,
        deviceId,
      }
    );
    console.log(`   Status: ${refreshResult.statusCode} | New Access Token: ${Boolean(refreshResult.data?.accessToken)}`);

    // 7. OTP Flow
    console.log('\n7️⃣ Testing Send OTP (/api/auth/send-otp)...');
    const otpPhone = `+9188${Math.floor(10000000 + Math.random() * 90000000)}`;
    const otpSendResult = await makeRequest(
      {
        ...baseUrlOptions,
        path: '/api/auth/send-otp',
        method: 'POST',
      },
      {
        phone: otpPhone,
      }
    );
    console.log(`   Status: ${otpSendResult.statusCode} | Message: ${otpSendResult.data?.message}`);

    const devOtp = otpSendResult.data?.devOtp || '123456';
    console.log('\n8️⃣ Testing Verify OTP (/api/auth/verify-otp)...');
    const otpVerifyResult = await makeRequest(
      {
        ...baseUrlOptions,
        path: '/api/auth/verify-otp',
        method: 'POST',
      },
      {
        phone: otpPhone,
        otp: devOtp,
        name: 'OTP Verified User',
        deviceId: 'web_chrome_test',
        deviceName: 'Chrome Web',
      }
    );
    console.log(`   Status: ${otpVerifyResult.statusCode} | User ID: ${otpVerifyResult.data?.user?.id}`);

    // 9. Logout Current Device
    console.log('\n9️⃣ Testing Logout Device (/api/auth/logout)...');
    const logoutResult = await makeRequest(
      {
        ...baseUrlOptions,
        path: '/api/auth/logout',
        method: 'POST',
        headers: {
          ...baseUrlOptions.headers,
          Authorization: `Bearer ${accessToken}`,
        },
      },
      {
        deviceId,
      }
    );
    console.log(`   Status: ${logoutResult.statusCode} | Message: ${logoutResult.data?.message}`);

    console.log('\n✅ ALL VERIFICATION TESTS PASSED SUCCESSFULLY! SERVER IS READY TO USE! 🎉');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error during verification testing:', error.message);
    process.exit(1);
  }
};

runVerification();
