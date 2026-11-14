const mongoose = require('mongoose');
const Business = require('../src/models/Business');
const User = require('../src/models/User');
const Campaign = require('../src/models/Campaign');
const watcher = require('../src/services/dbWatcherService');
const socket = require('../src/services/socketService');
const cron = require('../src/services/cronService');
const notification = require('../src/services/notificationService');
const campaign = require('../src/services/campaignService');
require('./setup');

describe('Canonical background entitlement decisions', () => {
  let businessId, ownerId;
  const future = () => new Date(Date.now() + 86400000);
  beforeEach(async () => {
    ownerId = new mongoose.Types.ObjectId();
    businessId = new mongoose.Types.ObjectId();
    await User.collection.insertOne({ _id: ownerId, email: 'background@example.com', status: 'active' });
    await Business.collection.insertOne({ _id: businessId, ownerId, isSubscription: true,
      subscriptionExpiresAt: future(), isChotuAiActive: true, subscription: { isActive: false } });
    watcher._lastBusinessState.clear();
  });
  afterEach(() => jest.restoreAllMocks());

  test('poll broadcasts calculated canonical status, never synchronizes legacy writes', async () => {
    const emit = jest.spyOn(socket, 'emitSubscriptionUpdated').mockImplementation(() => {});
    await watcher.pollOnce();
    expect(emit).not.toHaveBeenCalled();
    await Business.collection.updateOne({ _id: businessId }, { $set: { isChotuAiActive: false } });
    const before = await Business.collection.findOne({ _id: businessId });
    await watcher.pollOnce();
    expect(emit.mock.calls[0][1]).toMatchObject({ isActive: true, chotuAiAccess: false });
    expect(await Business.collection.findOne({ _id: businessId })).toEqual(before);
    await Business.collection.updateOne({ _id: businessId }, { $set: { subscriptionExpiresAt: new Date(0) } });
    await watcher.pollOnce();
    expect(emit.mock.calls[1][1]).toMatchObject({ isSubscription: true, isActive: false, status: 'expired' });
    expect((await Business.collection.findOne({ _id: businessId })).isSubscription).toBe(true);
  });

  test('legacy active mirror cannot publish an active subscription', async () => {
    const emit = jest.spyOn(socket, 'emitSubscriptionUpdated').mockImplementation(() => {});
    await Business.collection.updateOne({ _id: businessId }, { $set: { isSubscription: false, 'subscription.isActive': true } });
    await watcher.notify(businessId);
    expect(emit.mock.calls[0][1]).toMatchObject({ isActive: false, chotuAiAccess: false });
  });

  test('expiry reminders use canonical flags and finite BSON expiry', async () => {
    const send = jest.spyOn(notification, 'createNotification').mockResolvedValue({});
    await cron.checkExpiringSubscriptionsJob();
    expect(send).toHaveBeenCalledTimes(1);
    expect(String(send.mock.calls[0][0].businessId)).toBe(String(businessId));
    send.mockClear();
    await Business.collection.updateOne({ _id: businessId }, { $set: { isSubscription: false, 'subscription.isActive': true, 'subscription.expiresAt': future() } });
    await cron.checkExpiringSubscriptionsJob();
    expect(send).not.toHaveBeenCalled();
    await Business.collection.updateOne({ _id: businessId }, { $set: { isSubscription: true, subscriptionExpiresAt: future().toISOString() } });
    await cron.checkExpiringSubscriptionsJob();
    expect(send).not.toHaveBeenCalled();
  });

  test('scheduled campaign cannot charge or dispatch for an inactive business', async () => {
    await Business.collection.updateOne({ _id: businessId }, { $set: { isSubscription: false } });
    const save = jest.fn();
    jest.spyOn(Campaign, 'findById').mockResolvedValue({ businessId, save });
    await expect(campaign.executeScheduledCampaign(new mongoose.Types.ObjectId())).rejects.toMatchObject({ statusCode: 403, code: 'SUBSCRIPTION_REQUIRED' });
    expect(save).not.toHaveBeenCalled();
  });

  test('scheduler leaves disabled campaigns queued and retries after a manual extension', async () => {
    const queued = { _id: new mongoose.Types.ObjectId(), businessId, name: 'Queued campaign' };
    jest.spyOn(Campaign, 'find').mockReturnValue({ select: () => ({ lean: async () => [queued] }) });
    const lock = jest.spyOn(Campaign, 'findOneAndUpdate').mockResolvedValue(queued);
    const execute = jest.spyOn(campaign, 'executeScheduledCampaign').mockResolvedValue(queued);
    await Business.collection.updateOne({ _id: businessId }, { $set: { subscriptionExpiresAt: new Date(0) } });
    await cron.processScheduledCampaignsJob();
    expect(lock).not.toHaveBeenCalled();
    expect(execute).not.toHaveBeenCalled();
    await Business.collection.updateOne({ _id: businessId }, { $set: { subscriptionExpiresAt: future() } });
    await cron.processScheduledCampaignsJob();
    expect(lock).toHaveBeenCalledTimes(1);
    expect(execute).toHaveBeenCalledWith(queued._id);
  });
});
