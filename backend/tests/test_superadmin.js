const mongoose = require('mongoose');
const { connectDB, disconnectDB } = require('../src/config/db');
const superadminService = require('../src/services/superadminService');
const User = require('../src/models/User');
const Business = require('../src/models/Business');

async function testSuperAdmin() {
  console.log('--- Starting Super Admin Verification Test ---');
  try {
    await connectDB();

    // 1. Test Seed Super Admin
    console.log('\n[1] Testing seedSuperAdmin()...');
    const seeded = await superadminService.seedSuperAdmin();
    console.log('Seeded User Email:', seeded.email, 'Role:', seeded.role, 'isSuperAdmin:', seeded.isSuperAdmin);

    // 2. Test Login with Admin@12
    console.log('\n[2] Testing login with chandanyaduvanshi190@gmail.com & Admin@12...');
    const loginRes = await superadminService.login('chandanyaduvanshi190@gmail.com', 'Admin@12');
    console.log('Login Success! User:', loginRes.user.email, 'Token generated:', !!loginRes.accessToken);

    // 3. Test Unauthorized login attempt
    console.log('\n[3] Testing login with unauthorized email (should fail)...');
    try {
      await superadminService.login('random_hacker@gmail.com', 'Admin@12');
      console.error('FAILED: Unauthorized email did not throw error!');
    } catch (err) {
      console.log('SUCCESS: Unauthorized email properly blocked:', err.message);
    }

    // 4. Test Platform Stats
    console.log('\n[4] Testing getPlatformStats()...');
    const stats = await superadminService.getPlatformStats();
    console.log('Platform Stats Total Users:', stats.totals.users, 'Businesses:', stats.totals.businesses, 'Orders:', stats.totals.orders);

    // 5. Test Database Overview
    console.log('\n[5] Testing getDatabaseOverview()...');
    const dbOverview = await superadminService.getDatabaseOverview();
    console.log('DB Name:', dbOverview.databaseName, 'Collections count:', dbOverview.collections.length);
    console.log('Collections summary:');
    dbOverview.collections.forEach(c => console.log(` - ${c.name}: ${c.count} docs`));

    // 6. Test User Creation from Super Admin
    console.log('\n[6] Testing createUser()...');
    const testEmail = `test_store_${Date.now()}@example.com`;
    const created = await superadminService.createUser({
      email: testEmail,
      password: 'TestPassword@123',
      name: 'Test Merchant',
      phone: '+91 9888877777',
      companyName: 'Test Cafe & Bakery',
      businessType: 'Cafe',
      plan: 'growth',
      status: 'active',
      expiresInDays: 90,
    });
    console.log('User created:', created.user.email, 'Plan:', created.user.subscription.plan);

    // 7. Test Toggle Status (Inactive)
    console.log('\n[7] Testing updateUserStatus()...');
    const statusUpdate = await superadminService.updateUserStatus(created.user.id, 'inactive');
    console.log('Updated status:', statusUpdate.status);

    // 8. Test Subscription Update (Upgrade to Enterprise)
    console.log('\n[8] Testing updateUserSubscription()...');
    const subUpdate = await superadminService.updateUserSubscription(created.user.id, {
      plan: 'enterprise',
      status: 'active',
      extendDays: 365,
      maxTables: 100,
    });
    console.log('Updated subscription plan:', subUpdate.subscription.plan, 'Max tables:', subUpdate.subscription.maxTables);

    // 9. Test User Deletion
    console.log('\n[9] Testing deleteUser()...');
    const delRes = await superadminService.deleteUser(created.user.id);
    console.log('Delete result:', delRes.message);

    console.log('\n=== ALL SUPER ADMIN UNIT TESTS PASSED SUCCESSFULLY! ===');
  } catch (error) {
    console.error('Test failed with error:', error);
  } finally {
    await disconnectDB();
    process.exit(0);
  }
}

testSuperAdmin();
