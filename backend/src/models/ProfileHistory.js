const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const profileHistorySchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    previousProfile: {
      name: { type: String, default: '' },
      companyName: { type: String, default: '' },
      profileLogo: { type: String, default: '' },
      phone: { type: String, default: '' },
    },
    updatedProfile: {
      name: { type: String, default: '' },
      companyName: { type: String, default: '' },
      profileLogo: { type: String, default: '' },
      phone: { type: String, default: '' },
    },
    changedFields: [{ type: String }],
    changeReason: {
      type: String,
      default: 'Profile update from Business Settings Hub',
    },
    ipAddress: {
      type: String,
      default: '',
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

profileHistorySchema.plugin(tenantIsolationPlugin);

const ProfileHistory = mongoose.model('ProfileHistory', profileHistorySchema);

module.exports = ProfileHistory;
