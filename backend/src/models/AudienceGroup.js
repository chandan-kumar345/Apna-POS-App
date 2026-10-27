const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const contactNumberSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      default: 'Contact',
      trim: true,
    },
    phone: {
      type: String,
      required: true,
      trim: true,
    },
    addedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: true }
);

const audienceGroupSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    srNo: {
      type: Number,
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: [true, 'Group name is required'],
      trim: true,
    },
    type: {
      type: String,
      enum: ['Mobile', 'Customer', 'Excel/CSV', 'Segment'],
      default: 'Mobile',
      trim: true,
    },
    source: {
      type: String,
      default: 'Mobile source',
      trim: true,
    },
    description: {
      type: String,
      default: '',
      trim: true,
    },
    numbers: [contactNumberSchema],
    totalNumbers: {
      type: Number,
      default: 0,
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

audienceGroupSchema.index({ businessId: 1, name: 1 });
audienceGroupSchema.index({ businessId: 1, srNo: 1 });
audienceGroupSchema.index({ businessId: 1, createdAt: -1 });

audienceGroupSchema.pre('save', function (next) {
  if (this.numbers && Array.isArray(this.numbers)) {
    this.totalNumbers = this.numbers.length;
  }
  next();
});

audienceGroupSchema.plugin(tenantIsolationPlugin);

const AudienceGroup = mongoose.model('AudienceGroup', audienceGroupSchema);

module.exports = AudienceGroup;
