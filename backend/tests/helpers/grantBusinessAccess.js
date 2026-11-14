const Business = require('../../src/models/Business');
const tokenService = require('../../src/services/tokenService');

// Explicit fixture entitlement for positive-path integration suites. New users
// remain disabled in production; deny tests never call this helper.
module.exports = async function grantBusinessAccess(token) {
  const { sub } = tokenService.verifyAccessToken(token);
  await Business.updateOne({ ownerId: sub }, { $set: {
    isSubscription: true, subscriptionExpiresAt: new Date(Date.now() + 86400000), isChotuAiActive: true,
  } });
};
