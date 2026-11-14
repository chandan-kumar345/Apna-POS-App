const mongoose = require('mongoose');
const { planBusiness, migrate } = require('../src/services/entitlementMigration');
require('./setup');

describe('Entitlement migration', () => {
  const expiry = new Date('2030-01-01T00:00:00Z');
  beforeEach(async () => {
    // Raw migration fixtures are not all registered as Mongoose collections.
    await Promise.all(['businesses', 'users', 'premiumsubscriptions'].map((name) => mongoose.connection.db.collection(name).deleteMany({})));
  });
  test('maps finite consistent history and leaves expired enable flag intact', () => {
    const business = { _id: new mongoose.Types.ObjectId() };
    expect(planBusiness(business, [{ isActive: true, expiresAt: expiry }]).set).toEqual({ isSubscription: true, subscriptionExpiresAt: expiry, isChotuAiActive: false });
    expect(planBusiness(business, [{ isActive: true, expiresAt: new Date(0) }]).set.isSubscription).toBe(true);
  });
  test('conflicting, invalid and lifetime records need manual review without grants', () => {
    for (const sources of [[{ isActive: true, expiresAt: null }], [{ isActive: 'true', expiresAt: expiry }], [{ isActive: true, expiresAt: expiry }, { isActive: false, expiresAt: expiry }]]) {
      const plan = planBusiness({ _id: new mongoose.Types.ObjectId() }, sources);
      expect(plan.set).toEqual({});
      expect(plan.review.length).toBeGreaterThan(0);
    }
  });
  test('dry run does not mutate; apply is repeatable and preserves manual changes', async () => {
    const db = mongoose.connection.db;
    const id = new mongoose.Types.ObjectId();
    await db.collection('businesses').insertOne({ _id: id, ownerId: new mongoose.Types.ObjectId(), subscription: { isActive: true, expiresAt: expiry } });
    const dry = await migrate(db);
    expect(dry.mode).toBe('dry-run');
    expect((await db.collection('businesses').findOne({ _id: id })).isSubscription).toBeUndefined();
    await migrate(db, { apply: true });
    expect((await db.collection('businesses').findOne({ _id: id })).isSubscription).toBe(true);
    await db.collection('businesses').updateOne({ _id: id }, { $set: { isSubscription: false } });
    await migrate(db, { apply: true });
    expect((await db.collection('businesses').findOne({ _id: id })).isSubscription).toBe(false);
  });
  test('empty history disables with null expiry and reports voice preference for review', () => {
    const plan = planBusiness({ _id: new mongoose.Types.ObjectId(), orderSettings: { enableChotuVoice: true } });
    expect(plan.set).toEqual({ isSubscription: false, subscriptionExpiresAt: null, isChotuAiActive: false });
    expect(plan.review).toHaveLength(2);
  });
  test('does not combine contradictory partial canonical controls with legacy history', () => {
    const plan = planBusiness({ _id: new mongoose.Types.ObjectId(), isSubscription: true }, [{ isActive: false, expiresAt: expiry }]);
    expect(plan.set).toEqual({});
    expect(plan.review).toContain('Partial canonical flag contradicts legacy entitlement');
  });
  test('preserves the reported 17 November subscription when all legacy sources agree', () => {
    const paidExpiry = new Date('2026-11-17T06:43:19.746Z');
    const legacy = { isActive: true, isSubscriptionActive: true, status: 'active', expiresAt: paidExpiry };
    const plan = planBusiness({ _id: new mongoose.Types.ObjectId() }, [legacy, { ...legacy }, { ...legacy }]);
    expect(plan.review).toEqual([]);
    expect(plan.set).toMatchObject({ isSubscription: true, subscriptionExpiresAt: paidExpiry, isChotuAiActive: false });
    const { evaluate } = require('../src/services/entitlementService');
    expect(evaluate(plan.set, new Date('2026-11-14T00:00:00Z')).isActive).toBe(true);
    expect(evaluate(plan.set, paidExpiry).isActive).toBe(false);
  });
  test('maps a unique owner legacy record without granting it to multiple businesses', async () => {
    const db = mongoose.connection.db;
    const owner = new mongoose.Types.ObjectId();
    const id = new mongoose.Types.ObjectId();
    await db.collection('users').insertOne({ _id: owner, email: 'migration@example.com' });
    await db.collection('businesses').insertOne({ _id: id, ownerId: owner });
    await db.collection('premiumsubscriptions').insertOne({ userId: owner, targetType: 'user', isActive: true, expiresAt: expiry });
    expect((await migrate(db)).records[0].set.isSubscription).toBe(true);
    // Deliberately model ambiguous legacy data predating the unique owner index.
    if (mongoose.models.Business) {
      await mongoose.models.Business.init();
      await db.collection('businesses').dropIndex('ownerId_1');
    }
    await db.collection('businesses').insertOne({ ownerId: owner });
    const multiple = await migrate(db);
    expect(multiple.records.every((record) => record.set.isSubscription === false)).toBe(true);
  });
});
