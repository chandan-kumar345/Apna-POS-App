const mongoose = require('mongoose');

const tableSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    tableNumber: {
      type: Number,
      required: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    floor: {
      type: String,
      default: 'Ground Floor',
      trim: true,
    },
    capacity: {
      type: Number,
      default: 4,
      min: 1,
    },
    status: {
      type: String,
      enum: ['free', 'occupied', 'billed', 'reserved'],
      default: 'free',
      index: true,
    },
    currentOrderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
      default: null,
    },
    occupiedSince: {
      type: Date,
      default: null,
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

tableSchema.index({ businessId: 1, tableNumber: 1 }, { unique: true });
tableSchema.index({ businessId: 1, status: 1 });

const Table = mongoose.model('Table', tableSchema);

module.exports = Table;
