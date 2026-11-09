const mongoose = require('mongoose');

const customRingtoneSubSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    name: { type: String, required: true },
    url: { type: String, required: true },
    type: { type: String, enum: ['notification', 'order'], default: 'order' },
    sizeBytes: { type: Number, default: 0 },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: false }
);

const notificationSettingSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    // General Notification Ringtone
    notificationSound: {
      type: String,
      default: 'default',
    },
    notificationSoundName: {
      type: String,
      default: 'Default Apna POS (Chime)',
    },
    notificationSoundUrl: {
      type: String,
      default: 'sounds/Notification_sound.mp3',
    },
    notificationSoundType: {
      type: String,
      enum: ['default', 'preset', 'custom'],
      default: 'default',
    },

    // Urgent Incoming Order Accept Ringtone
    orderRingtone: {
      type: String,
      default: 'default',
    },
    orderRingtoneName: {
      type: String,
      default: 'Default Apna POS (Looping Alarm)',
    },
    orderRingtoneUrl: {
      type: String,
      default: 'sounds/order_recieve_ringtone.mp3',
    },
    orderRingtoneType: {
      type: String,
      enum: ['default', 'preset', 'custom'],
      default: 'default',
    },

    // Sound & Alert Behavior Preferences
    soundEnabled: {
      type: Boolean,
      default: true,
    },
    orderVolume: {
      type: Number,
      default: 1.0,
      min: 0.0,
      max: 1.0,
    },
    notificationVolume: {
      type: Number,
      default: 1.0,
      min: 0.0,
      max: 1.0,
    },
    vibrationEnabled: {
      type: Boolean,
      default: true,
    },
    autoOpenOrderScreen: {
      type: Boolean,
      default: true,
    },

    // Custom uploaded ringtones collection for this user
    customRingtones: {
      type: [customRingtoneSubSchema],
      default: [],
    },
  },
  {
    timestamps: true,
  }
);

// Compound unique index ensuring isolated user preferences per business
notificationSettingSchema.index({ businessId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('NotificationSetting', notificationSettingSchema);
