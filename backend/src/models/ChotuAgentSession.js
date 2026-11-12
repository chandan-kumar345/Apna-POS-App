const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  businessId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, required: true },
  sessionId: { type: String, required: true },
  tableNumber: { type: String, default: '' },
  stage: { type: String, default: 'draft' },
  orderId: { type: mongoose.Schema.Types.ObjectId, default: null },
  kitchenFingerprint: { type: String, default: '' },
  billFingerprint: { type: String, default: '' },
  pending: { type: mongoose.Schema.Types.Mixed, default: null },
}, { timestamps: true });
schema.index({ businessId: 1, userId: 1, sessionId: 1 }, { unique: true });
module.exports = mongoose.model('ChotuAgentSession', schema);
