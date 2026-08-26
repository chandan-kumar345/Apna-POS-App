const mongoose = require('mongoose');
const loyaltyService = require('../src/services/loyaltyService');
const Business = require('../src/models/Business');
const User = require('../src/models/User');
require('dotenv').config();

async function runLoyaltyTests() {
  console.log('Testing Loyalty Service, Auto-Seeding, and Endpoints...');
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/apna_pos';
  await mongoose.connect(mongoUri);
  console.log('✅ Connected to MongoDB');

  // Find a business
  let business = await Business.findOne();
  if (!business) {
    const user = await User.findOne();
    if (user) {
      business = await Business.create({
        ownerId: user._id,
        profile: { companyName: 'MISSION MEATZ', name: 'Mission Meatz Store' },
      });
    }
  }

  const businessId = business ? business._id : new mongoose.Types.ObjectId();
  console.log('Using Business ID:', businessId);

  // 1. Fetch Loyalty Programs
  const result = await loyaltyService.getLoyaltyPrograms(businessId);
  console.log('✅ Fetched Loyalty Programs:');
  console.log('   Company Name:', result.companyName);
  console.log('   Company Logo:', result.companyLogo || '(fallback placeholder)');
  console.log('   Programs Count:', result.programs.length);
  result.programs.forEach((p) => {
    console.log(`   - [${p.type}] ${p.title}: "${p.earningRule}" (milestones/slabs: ${p.milestones?.length || 1})`);
  });

  // 2. Fetch Loyalty Performance
  const perf = await loyaltyService.getLoyaltyPerformance(businessId);
  console.log('✅ Fetched Loyalty Performance:');
  console.log('   Total Members:', perf.totalMembers);
  console.log('   Active Members:', perf.activeMembers);
  console.log('   Rewards Claimed:', perf.rewardsClaimed);
  console.log('   ROI:', perf.roiPercentage);

  // 3. Test Update Program
  if (result.programs.length > 0) {
    const firstProg = result.programs[0];
    firstProg.description = 'Updated Description for test';
    await loyaltyService.updateLoyaltyProgram(businessId, firstProg);
    console.log('✅ Successfully updated loyalty program');
  }

  console.log('\n========================================');
  console.log('🎉 ALL LOYALTY BACKEND TESTS PASSED!');
  console.log('========================================');

  await mongoose.disconnect();
}

runLoyaltyTests().catch((err) => {
  console.error('❌ Loyalty test failed:', err);
  process.exit(1);
});
