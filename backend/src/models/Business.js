const mongoose = require('mongoose');

const pointSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      default: [0, 0],
    },
  },
  { _id: false }
);

const businessSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    profile: {
      profileImage: { type: String, default: '' },
      name: { type: String, default: '', trim: true },
      phone: { type: String, default: '', trim: true },
      companyName: { type: String, default: '', trim: true },
      website: { type: String, default: '', trim: true },
      referralCode: { type: String, default: '', trim: true },
    },
    business: {
      country: { type: String, default: 'IN', trim: true },
      currency: { type: String, default: 'INR', trim: true },
      timezone: { type: String, default: 'Asia/Kolkata', trim: true },
      businessType: { type: String, default: 'Restaurant', trim: true },
    },
    address: {
      addressLine: { type: String, default: '', trim: true },
      building: { type: String, default: '', trim: true },
      landmark: { type: String, default: '', trim: true },
      placeType: {
        type: String,
        enum: ['home', 'work', 'other'],
        default: 'work',
      },
      city: { type: String, default: '', trim: true },
      state: { type: String, default: '', trim: true },
      country: { type: String, default: 'IN', trim: true },
      postalCode: { type: String, default: '', trim: true },
      location: {
        type: pointSchema,
        default: () => ({ type: 'Point', coordinates: [0, 0] }),
      },
    },
    orderSettings: {
      services: {
        dineIn: { type: Boolean, default: true },
        takeaway: { type: Boolean, default: false },
        delivery: { type: Boolean, default: false },
      },
      tax: {
        type: {
          type: String,
          enum: ['gst', 'no_gst'],
          default: 'gst',
        },
        gstNumber: { type: String, default: '', trim: true },
        percentage: { type: Number, default: 5 },
      },
      restaurantType: {
        type: String,
        enum: ['pure_veg', 'non_veg', 'both'],
        default: 'both',
      },
      paymentMethods: {
        cash: { type: Boolean, default: true },
        upi: { type: Boolean, default: true },
        card: { type: Boolean, default: false },
      },
      upiId: { type: String, default: '', trim: true },
      tableCount: { type: Number, default: 0, min: 0 },
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

businessSchema.index({ 'address.location': '2dsphere' });

const Business = mongoose.model('Business', businessSchema);

module.exports = Business;
