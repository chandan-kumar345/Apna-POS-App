const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  businessId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, required: true },
  sessionId: { type: String, required: true },
  requestId: { type: String, required: true },
  payloadHash: { type: String, required: true },
  text: { type: String, required: true },
  intent: { type: String, default: '' },
  status: { type: String, enum: ['processing', 'completed', 'needs_review'], default: 'processing' },
  steps: { type: [String], default: [] },
  response: { type: mongoose.Schema.Types.Mixed, default: null },
}, { timestamps: true });
schema.index({ businessId: 1, userId: 1, sessionId: 1, requestId: 1 }, { unique: true });
module.exports = mongoose.model('ChotuAgentTurn', schema);
