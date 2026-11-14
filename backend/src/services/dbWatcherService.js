const Subscription = require('../models/Subscription');
const Business = require('../models/Business');
const socketService = require('./socketService');
const access = require('./entitlementService');

// Notifications only. Legacy ledger/user changes must never synchronize grants
// back into a business or publish a different access decision from the API.
class DbWatcherService {
  constructor() {
    this.isInitialized = false;
    this._lastBusinessState = new Map();
  }

  init() {
    if (this.isInitialized) return;
    this.isInitialized = true;
    this.watchBusinesses();
    this.watchSubscriptions();
    this.startPollingFallback();
  }

  async notify(businessId) {
    if (!businessId) return;
    const status = await access.status(businessId);
    socketService.emitSubscriptionUpdated(businessId, status);
  }

  watch(model, businessIdFor) {
    try {
      const stream = model.watch([], { fullDocument: 'updateLookup' });
      stream.on('change', async (change) => {
        if (!['insert', 'update', 'replace'].includes(change.operationType)) return;
        try { await this.notify(businessIdFor(change.fullDocument)); }
        catch (error) { console.error('[DbWatcherService] Notification failed:', error.message); }
      });
      // Standalone MongoDB does not support streams; the read-only poll remains.
      stream.on('error', () => {});
    } catch (_) { /* Polling fallback handles unavailable streams. */ }
  }

  watchBusinesses() { this.watch(Business, (doc) => doc?._id); }
  watchSubscriptions() { this.watch(Subscription, (doc) => doc?.businessId); }

  async pollOnce() {
    const businesses = await Business.collection.find({}, { projection: {
      isSubscription: 1, subscriptionExpiresAt: 1, isChotuAiActive: 1,
    } }).toArray();
    const seen = new Set();
    for (const business of businesses) {
      const key = String(business._id);
      seen.add(key);
      const state = JSON.stringify(access.evaluate(business));
      if (this._lastBusinessState.has(key) && this._lastBusinessState.get(key) !== state) {
        await this.notify(business._id);
      }
      this._lastBusinessState.set(key, state);
    }
    for (const key of this._lastBusinessState.keys()) {
      if (!seen.has(key)) this._lastBusinessState.delete(key);
    }
  }

  startPollingFallback() {
    if (this._pollingInterval) return;
    this._pollingInterval = setInterval(async () => {
      if (this._polling) return;
      this._polling = true;
      try { await this.pollOnce(); }
      catch (error) { console.error('[DbWatcherService] Poll failed:', error.message); }
      finally { this._polling = false; }
    }, 5000);
    this._pollingInterval.unref?.();
  }
}

module.exports = new DbWatcherService();
