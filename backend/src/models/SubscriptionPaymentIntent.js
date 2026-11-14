const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  businessId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  providerOrderId: { type: String, required: true, unique: true },
  amount: { type: Number, required: true, min: 1 },
  currency: { type: String, required: true, enum: ['INR'] },
  days: { type: Number, required: true, min: 1, max: 366 },
}, { timestamps: true });
module.exports = mongoose.model('SubscriptionPaymentIntent', schema);
