const mongoose = require('mongoose');

const whatsAppMessageSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    chatId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'WhatsAppChat',
      required: true,
      index: true,
    },
    customerPhone: {
      type: String,
      required: true,
      trim: true,
    },
    direction: {
      type: String,
      enum: ['INCOMING', 'OUTGOING'],
      required: true,
    },
    messageType: {
      type: String,
      enum: ['text', 'image', 'document', 'template', 'interactive', 'button'],
      default: 'text',
    },
    text: {
      type: String,
      default: '',
    },
    mediaUrl: {
      type: String,
      default: '',
    },
    whatsappMessageId: {
      type: String,
      default: '',
      index: true,
    },
    status: {
      type: String,
      enum: ['PENDING', 'SENT', 'DELIVERED', 'READ', 'FAILED'],
      default: 'SENT',
    },
    error: {
      type: String,
      default: null,
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
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

whatsAppMessageSchema.index({ chatId: 1, timestamp: 1 });
whatsAppMessageSchema.index({ businessId: 1, timestamp: -1 });

const WhatsAppMessage = mongoose.model('WhatsAppMessage', whatsAppMessageSchema);

module.exports = WhatsAppMessage;
