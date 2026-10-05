const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      trim: true,
      lowercase: true,
      index: true,
      match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email address'],
    },
    phone: {
      type: String,
      trim: true,
      sparse: true,
      index: true,
    },
    passwordHash: {
      type: String,
      required: [true, 'Password hash is required'],
      select: false, // Never return password hash by default
    },

    role: {
      type: String,
      trim: true,
      default: 'owner',
    },
    status: {
      type: String,
      enum: ['active', 'inactive', 'suspended'],
      default: 'active',
      index: true,
    },
    isSuperAdmin: {
      type: Boolean,
      default: false,
      index: true,
    },
    subscription: {
      plan: {
        type: String,
        default: 'starter',
      },
      status: {
        type: String,
        enum: ['active', 'trial', 'expired', 'cancelled', 'inactive'],
        default: 'active',
      },
      isActive: {
        type: Boolean,
        default: true,
      },
      startDate: {
        type: Date,
        default: Date.now,
      },
      expiresAt: {
        type: Date,
        default: () => new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
      },
      billingCycle: {
        type: String,
        enum: ['monthly', 'annual', 'lifetime'],
        default: 'annual',
      },
      maxTables: {
        type: Number,
        default: 50,
      },
      maxStaff: {
        type: Number,
        default: 20,
      },
      notes: {
        type: String,
        default: '',
      },
    },
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      index: true,
    },
    staffId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Staff',
      index: true,
    },
    emailVerified: {
      type: Boolean,
      default: false,
    },
    phoneVerified: {
      type: Boolean,
      default: false,
    },
    onboardingCompleted: {
      type: Boolean,
      default: false,
      index: true,
    },
    onboardingStep: {
      type: Number,
      default: 0,
      min: 0,
      max: 4,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        delete ret.passwordHash;
        return ret;
      },
    },
  }
);

// Method to verify password
userSchema.methods.comparePassword = async function (plainPassword) {
  return bcrypt.compare(plainPassword, this.passwordHash);
};

// Static method to hash password
userSchema.statics.hashPassword = async function (plainPassword) {
  const salt = await bcrypt.genSalt(12);
  return bcrypt.hash(plainPassword, salt);
};

const User = mongoose.model('User', userSchema);

module.exports = User;
