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

    // Always run polling fallback for standalone MongoDB instances (e.g. local Compass)
    this.startPollingFallback();
  }

  watchSubscriptions() {
    try {
      const changeStream = Subscription.watch([], { fullDocument: 'updateLookup' });

      changeStream.on('change', async (change) => {
        try {
          if (['update', 'replace', 'insert'].includes(change.operationType)) {
            const doc = change.fullDocument;
            if (doc) {
              let isActive = true;
              if (doc.isSubscriptionActive !== undefined && doc.isSubscriptionActive !== null) {
                isActive = Boolean(doc.isSubscriptionActive);
              } else if (doc.isActive !== undefined && doc.isActive !== null) {
                isActive = Boolean(doc.isActive);
              } else if (doc.isSubscribed !== undefined && doc.isSubscribed !== null) {
                isActive = Boolean(doc.isSubscribed);
              } else if (doc.status !== undefined && doc.status !== null) {
                isActive = doc.status === 'active';
              }

              console.log(`[Compass Real-Time Update] Subscription modified: ${doc._id}, isActive: ${isActive}, target: ${doc.targetType}`);

              // Broadcast real-time socket event
              socketService.emitSubscriptionUpdated(doc.businessId, {
                subscriptionId: doc._id,
                businessId: doc.businessId,
                userId: doc.userId,
                staffId: doc.staffId,
                targetType: doc.targetType,
                isSubscriptionActive: isActive,
                isActive,
                isSubscribed: isActive,
                status: isActive ? 'active' : 'inactive',
                plan: doc.plan || 'standard',
                expiresAt: doc.expiresAt,
              });

              // Keep Business & User models in sync ONLY if state actually differs to prevent infinite circular streams
              if (doc.businessId) {
                const b = await Business.findById(doc.businessId, 'subscription').lean();
                if (b && (b.subscription?.isActive !== isActive || b.subscription?.status !== (isActive ? 'active' : 'inactive'))) {
                  await Business.findByIdAndUpdate(doc.businessId, {
                    $set: {
                      'subscription.isActive': isActive,
                      'subscription.isSubscriptionActive': isActive,
                      'subscription.status': isActive ? 'active' : 'inactive',
                    },
                  });
                }
              }
              if (doc.userId) {
                const u = await User.findById(doc.userId, 'subscription').lean();
                if (u && (u.subscription?.isActive !== isActive || u.subscription?.status !== (isActive ? 'active' : 'inactive'))) {
                  await User.findByIdAndUpdate(doc.userId, {
                    $set: {
                      'subscription.isActive': isActive,
                      'subscription.isSubscriptionActive': isActive,
                      'subscription.status': isActive ? 'active' : 'inactive',
                    },
                  });
                }
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

              // Check if Subscription collection already matches before updating to prevent infinite ping-pong loop!
              const existingSub = await Subscription.findOne({ businessId: doc._id }).lean();
              if (existingSub) {
                const subActive = existingSub.isActive !== undefined
                  ? Boolean(existingSub.isActive)
                  : (existingSub.status === 'active');
                if (subActive !== isActive) {
                  console.log(`[Compass Real-Time Update] Business ${doc._id} subscription modified: isActive = ${isActive}`);
                  await Subscription.findOneAndUpdate(
                    { businessId: doc._id },
                    {
                      $set: {
                        isActive,
                        isSubscriptionActive: isActive,
                        isSubscribed: isActive,
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
                    isSubscriptionActive: isActive,
                    isSubscribed: isActive,
                    status: isActive ? 'active' : 'inactive',
                    plan: doc.subscription.plan || 'standard',
                    expiresAt: doc.subscription.expiresAt,
                  });
                }
              }
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

              const existingSub = await Subscription.findOne({ userId: doc._id }).lean();
              if (existingSub) {
                const subActive = existingSub.isActive !== undefined
                  ? Boolean(existingSub.isActive)
                  : (existingSub.status === 'active');
                if (subActive !== isActive) {
                  console.log(`[Compass Real-Time Update] User ${doc._id} subscription modified: isActive = ${isActive}`);
                  await Subscription.findOneAndUpdate(
                    { userId: doc._id },
                    {
                      $set: {
                        isActive,
                        isSubscriptionActive: isActive,
                        isSubscribed: isActive,
                        status: isActive ? 'active' : 'inactive',
                      },
                    }
                  );

                  socketService.emitSubscriptionUpdated(doc.businessId, {
                    businessId: doc.businessId,
                    userId: doc._id,
                    isActive,
                    isSubscriptionActive: isActive,
                    isSubscribed: isActive,
                    status: isActive ? 'active' : 'inactive',
                  });
                }
              }
            }
          }
        } catch (err) {}
      });

      changeStream.on('error', () => {});
    } catch (err) {}
  }

  startPollingFallback() {
    if (this._pollingInterval) return;
    this._lastSubState = new Map();

    this._pollingInterval = setInterval(async () => {
      try {
        const subs = await Subscription.find(
          {},
          '_id businessId userId staffId targetType isActive isSubscriptionActive isSubscribed status plan expiresAt updatedAt'
        ).lean();

        for (const sub of subs) {
          const key = sub._id.toString();
          let currentActive = true;
          if (sub.isSubscriptionActive !== undefined && sub.isSubscriptionActive !== null) {
            currentActive = Boolean(sub.isSubscriptionActive);
          } else if (sub.isActive !== undefined && sub.isActive !== null) {
            currentActive = Boolean(sub.isActive);
          } else if (sub.isSubscribed !== undefined && sub.isSubscribed !== null) {
            currentActive = Boolean(sub.isSubscribed);
          } else if (sub.status !== undefined && sub.status !== null) {
            currentActive = sub.status === 'active';
          }

          // Initial seeding: avoid false-positive update trigger on server boot
          if (!this._lastSubState.has(key)) {
            this._lastSubState.set(key, currentActive);
            continue;
          }

          const previousActive = this._lastSubState.get(key);
          if (previousActive !== currentActive) {
            console.log(
              `[Compass Polling Fallback] Subscription ${key} active state changed: ${previousActive} -> ${currentActive}`
            );

            // Broadcast real-time socket event
            socketService.emitSubscriptionUpdated(sub.businessId, {
              subscriptionId: sub._id,
              businessId: sub.businessId,
              userId: sub.userId,
              staffId: sub.staffId,
              targetType: sub.targetType,
              isSubscriptionActive: currentActive,
              isActive: currentActive,
              isSubscribed: currentActive,
              status: currentActive ? 'active' : 'inactive',
              plan: sub.plan || 'standard',
              expiresAt: sub.expiresAt,
            });

            // Keep Business & User models in sync only if different
            if (sub.businessId) {
              const b = await Business.findById(sub.businessId, 'subscription').lean();
              if (b && (b.subscription?.isActive !== currentActive || b.subscription?.status !== (currentActive ? 'active' : 'inactive'))) {
                await Business.findByIdAndUpdate(sub.businessId, {
                  $set: {
                    'subscription.isActive': currentActive,
                    'subscription.isSubscriptionActive': currentActive,
                    'subscription.status': currentActive ? 'active' : 'inactive',
                  },
                });
              }
            }
            if (sub.userId) {
              const u = await User.findById(sub.userId, 'subscription').lean();
              if (u && (u.subscription?.isActive !== currentActive || u.subscription?.status !== (currentActive ? 'active' : 'inactive'))) {
                await User.findByIdAndUpdate(sub.userId, {
                  $set: {
                    'subscription.isActive': currentActive,
                    'subscription.isSubscriptionActive': currentActive,
                    'subscription.status': currentActive ? 'active' : 'inactive',
                  },
                });
              }
            }
          }
          this._lastSubState.set(key, currentActive);
        }
      } catch (err) {
        // Silently continue polling
      }
    }, 5000);
  }
}

module.exports = new DbWatcherService();
