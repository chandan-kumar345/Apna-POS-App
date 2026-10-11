const mongoose = require('mongoose');

const whatsAppChatSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    phoneNumberId: {
      type: String,
      default: '',
      trim: true,
    },
    customerPhone: {
      type: String,
      required: true,
      trim: true,
    },
    customerName: {
      type: String,
      default: '',
      trim: true,
    },
    lastMessage: {
      type: String,
      default: '',
    },
    lastMessageAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    lastMessageDirection: {
      type: String,
      enum: ['INCOMING', 'OUTGOING'],
      default: 'INCOMING',
    },
    unreadCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'ARCHIVED'],
      default: 'ACTIVE',
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

whatsAppChatSchema.index({ businessId: 1, customerPhone: 1 }, { unique: true });
whatsAppChatSchema.index({ businessId: 1, lastMessageAt: -1 });

const WhatsAppChat = mongoose.model('WhatsAppChat', whatsAppChatSchema);

module.exports = WhatsAppChat;
