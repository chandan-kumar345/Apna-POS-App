const mongoose = require('mongoose');

// Deliberately no TTL: interrupted financial/order writes require reconciliation.
const schema = new mongoose.Schema({
  businessId: { type: mongoose.Schema.Types.ObjectId, required: true },
  resource: { type: String, required: true },
  token: { type: String, required: true },
  sessionId: { type: String, required: true },
  requestId: { type: String, required: true },
}, { timestamps: true });
schema.index({ businessId: 1, resource: 1 }, { unique: true });
module.exports = mongoose.model('ChotuAgentLock', schema);
