const mongoose = require('mongoose');

const staffSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: [true, 'Staff name is required'],
      trim: true,
    },
    employeeId: {
      type: String,
      trim: true,
      index: true,
    },
    phone: {
      type: String,
      trim: true,
      default: '',
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      default: '',
    },
    role: {
      type: String,
      enum: ['Admin', 'Manager', 'Cashier', 'Sales', 'Inventory', 'Support', 'Chef', 'Waiter', 'Other'],
      default: 'Cashier',
    },
    status: {
      type: String,
      enum: ['Active', 'Inactive'],
      default: 'Active',
      index: true,
    },
    pin: {
      type: String,
      trim: true,
      default: '1234',
    },
    avatarUrl: {
      type: String,
      default: '',
    },
    permissions: {
      type: [String],
      default: ['pos', 'tables', 'orders'],
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    department: {
      type: String,
      trim: true,
      default: '',
    },
    workLocation: {
      type: String,
      trim: true,
      default: '',
    },
    reportingTo: {
      type: String,
      trim: true,
      default: '',
    },
    forcePasswordChange: {
      type: Boolean,
      default: false,
    },
    shift: {
      type: String,
      trim: true,
      default: 'Morning Shift (8 AM - 4 PM)',
    },
    language: {
      type: String,
      trim: true,
      default: 'English',
    },
    theme: {
      type: String,
      trim: true,
      default: 'Light',
    },
    defaultScreen: {
      type: String,
      trim: true,
      default: 'Dashboard',
    },
    enableBiometric: {
      type: Boolean,
      default: false,
    },
    sendWelcomeEmail: {
      type: Boolean,
      default: true,
    },
    lastLogin: {
      type: Date,
    },
    lastLoginDevice: {
      type: String,
      default: 'From Windows',
    },
    salary: {
      type: Number,
      default: 0,
    },
    joiningDate: {
      type: Date,
      default: Date.now,
    },
    notes: {
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

staffSchema.index({ businessId: 1, employeeId: 1 });
staffSchema.index({ businessId: 1, status: 1 });
staffSchema.index({ businessId: 1, role: 1 });

const Staff = mongoose.model('Staff', staffSchema);

module.exports = Staff;
