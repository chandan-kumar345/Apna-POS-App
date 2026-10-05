const Subscription = require('../models/Subscription');
const Business = require('../models/Business');
const User = require('../models/User');
const socketService = require('./socketService');
const subscriptionService = require('./subscriptionService');

class DbWatcherService {
  constructor() {
    this.isInitialized = false;
  }

  /**
   * Initialize MongoDB Real-Time Change Streams for Compass updates
   */
  init() {
    if (this.isInitialized) return;
    this.isInitialized = true;

    try {
      this.watchSubscriptions();
      this.watchBusinesses();
      this.watchUsers();
      console.log('[DbWatcherService] MongoDB Compass Realtime Watchers Initialized');
    } catch (err) {
      console.log('[DbWatcherService] Change Streams initialization info:', err.message);
    }
  }

  watchSubscriptions() {
    try {
      const changeStream = Subscription.watch([], { fullDocument: 'updateLookup' });

      changeStream.on('change', async (change) => {
        try {
          if (['update', 'replace', 'insert'].includes(change.operationType)) {
            const doc = change.fullDocument;
            if (doc) {
              const isActive = doc.isActive !== undefined ? Boolean(doc.isActive) : (doc.status === 'active');
              console.log(`[Compass Real-Time Update] Subscription modified: ${doc._id}, isActive: ${isActive}, target: ${doc.targetType}`);

              // Broadcast instant socket event to all clients
              socketService.emitSubscriptionUpdated(doc.businessId, {
                subscriptionId: doc._id,
                businessId: doc.businessId,
                userId: doc.userId,
                staffId: doc.staffId,
                targetType: doc.targetType,
                isActive,
                status: isActive ? 'active' : 'inactive',
                plan: doc.plan || 'standard',
                expiresAt: doc.expiresAt,
              });

              // Keep Business & User models in sync
              if (doc.businessId) {
                await Business.findByIdAndUpdate(doc.businessId, {
                  $set: {
                    'subscription.isActive': isActive,
                    'subscription.status': isActive ? 'active' : 'inactive',
                  },
                });
              }
              if (doc.userId) {
                await User.findByIdAndUpdate(doc.userId, {
                  $set: {
                    'subscription.isActive': isActive,
                    'subscription.status': isActive ? 'active' : 'inactive',
                  },
                });
              }
            }
          }
        } catch (err) {
          console.error('[DbWatcherService.watchSubscriptions] Error processing change:', err.message);
        }
      });

      changeStream.on('error', (err) => {
        console.log('[DbWatcherService.watchSubscriptions] Stream connection notification:', err.message);
      });
    } catch (err) {
      console.log('[DbWatcherService.watchSubscriptions] Stream setup notice:', err.message);
    }
  }

  watchBusinesses() {
    try {
      const changeStream = Business.watch([], { fullDocument: 'updateLookup' });

      changeStream.on('change', async (change) => {
        try {
          if (['update', 'replace'].includes(change.operationType)) {
            const doc = change.fullDocument;
            if (doc && doc.subscription) {
              const isActive = doc.subscription.isActive !== undefined
                ? Boolean(doc.subscription.isActive)
                : (doc.subscription.status === 'active');

              console.log(`[Compass Real-Time Update] Business ${doc._id} subscription modified: isActive = ${isActive}`);

              // Update or sync with Subscription collection
              await Subscription.findOneAndUpdate(
                { businessId: doc._id },
                {
                  $set: {
                    isActive,
                    status: isActive ? 'active' : 'inactive',
                    ...(doc.subscription.plan && { plan: doc.subscription.plan }),
                    ...(doc.subscription.amount && { amount: Number(doc.subscription.amount) }),
                    ...(doc.subscription.expiresAt && { expiresAt: new Date(doc.subscription.expiresAt) }),
                  },
                }
              );

              socketService.emitSubscriptionUpdated(doc._id, {
                businessId: doc._id,
                userId: doc.ownerId,
                isActive,
                status: isActive ? 'active' : 'inactive',
                plan: doc.subscription.plan || 'standard',
                expiresAt: doc.subscription.expiresAt,
              });
            }
          }
        } catch (err) {
          console.error('[DbWatcherService.watchBusinesses] Error processing change:', err.message);
        }
      });

      changeStream.on('error', () => {});
    } catch (err) {}
  }

  watchUsers() {
    try {
      const changeStream = User.watch([], { fullDocument: 'updateLookup' });

      changeStream.on('change', async (change) => {
        try {
          if (['update', 'replace'].includes(change.operationType)) {
            const doc = change.fullDocument;
            if (doc && doc.subscription) {
              const isActive = doc.subscription.isActive !== undefined
                ? Boolean(doc.subscription.isActive)
                : (doc.subscription.status === 'active');

              console.log(`[Compass Real-Time Update] User ${doc._id} subscription modified: isActive = ${isActive}`);

              socketService.emitSubscriptionUpdated(doc.businessId, {
                businessId: doc.businessId,
                userId: doc._id,
                isActive,
                status: isActive ? 'active' : 'inactive',
              });
            }
          }
        } catch (err) {}
      });

      changeStream.on('error', () => {});
    } catch (err) {}
  }
}

module.exports = new DbWatcherService();
