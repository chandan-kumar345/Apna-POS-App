const mongoose = require('mongoose');

const chotuActionLogSchema = new mongoose.Schema(
  {
    restaurantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    sessionId: {
      type: String,
      default: '',
      index: true,
    },
    audioReference: {
      type: String,
      default: '',
    },
    transcription: {
      type: String,
      required: true,
      trim: true,
    },
    intent: {
      type: String,
      default: 'TRANSCRIBE_ONLY',
      index: true,
    },
    commandJson: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    confidence: {
      type: Number,
      default: 1.0,
      min: 0,
      max: 1,
    },
    actionStatus: {
      type: String,
      enum: ['pending', 'transcribed', 'validated', 'confirmed', 'executed', 'failed', 'rejected'],
      default: 'transcribed',
      index: true,
    },
    errorMessage: {
      type: String,
      default: '',
    },
    tableId: {
      type: String,
      default: '',
    },
    tableNumber: {
      type: String,
      default: '',
    },
    orderId: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    kotId: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    billId: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    confirmationRequired: {
      type: Boolean,
      default: false,
    },
    confirmed: {
      type: Boolean,
      default: false,
    },
    executionTimeMs: {
      type: Number,
      default: 0,
    },
    language: {
      type: String,
      default: 'hinglish',
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id ? ret._id.toString() : ret.id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

chotuActionLogSchema.index({ restaurantId: 1, createdAt: -1 });
chotuActionLogSchema.index({ restaurantId: 1, intent: 1, createdAt: -1 });

const ChotuActionLog = mongoose.model('ChotuActionLog', chotuActionLogSchema);

module.exports = ChotuActionLog;
