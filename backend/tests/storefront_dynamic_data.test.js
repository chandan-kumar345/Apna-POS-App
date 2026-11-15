require('./setup');
const mongoose = require('mongoose');
const Business = require('../src/models/Business');
const Product = require('../src/models/Product');
const Category = require('../src/models/Category');
const storefront = require('../src/controllers/storefrontController');
const profile = require('../src/controllers/profileController');

async function invoke(method, req) {
  let result;
  const res = { status: jest.fn().mockReturnThis(), json: body => { result = body; } };
  await method(req, res, error => { throw error; });
  return result;
}

describe('Public storefront API data', () => {
  let business;
  beforeEach(async () => {
    business = await Business.create({
      ownerId: new mongoose.Types.ObjectId(),
      profile: { companyName: 'River Kitchen', slug: 'river-kitchen', phone: '9876543210', tagline: 'Fresh daily' },
      address: { addressLine: '12 River Road', city: 'Delhi', postalCode: '110001' },
      orderSettings: { services: { dineIn: false, delivery: true, takeaway: true }, openingTime: '10:00 AM', closingTime: '10:00 PM', tableCount: 0 },
      storefront: { themeColorHex: 0xFF187C65, deliveryEta: '25–35 min', banners: [
        { id: 'offer', headline: 'Lunch specials', couponCode: 'LUNCH', displayOrder: 2 },
        { id: 'inactive', headline: 'Expired', isActive: false },
      ] },
    });
  });

  test('returns the selected restaurant configuration and catalog only', async () => {
    const other = await Business.create({ ownerId: new mongoose.Types.ObjectId(), profile: { companyName: 'Other', slug: 'other' } });
    await Product.create([
      { businessId: business._id, name: 'Garden Pizza', category: 'Pizza', price: 249, videoUrl: 'https://media.example/pizza.mp4' },
      { businessId: other._id, name: 'Private other menu', category: 'Other', price: 1 },
    ]);
    await Category.create({ businessId: business._id, name: 'Pizza' });
    const { data } = await invoke(storefront.getStorefront, { params: { slug: 'river-kitchen' }, query: {} });
    expect(data.restaurant).toMatchObject({ name: 'River Kitchen', address: '12 River Road, Delhi, 110001', openingTime: '10:00 AM', services: ['Takeaway', 'Delivery'] });
    expect(data.themeColorHex).toBe(0xFF187C65);
    expect(data.deliveryEta).toBe('25–35 min');
    expect(data.products.map(p => p.name)).toEqual(['Garden Pizza']);
    expect(data.products[0].videoUrl).toBe('https://media.example/pizza.mp4');
    expect(data.categories).toEqual(['Pizza']);
    expect(data.banners.map(b => b.id)).toEqual(['offer']);
    expect(data.restaurant.rating).toBeUndefined();
  });

  test('branding loads without querying the catalog; empty catalogs stay empty', async () => {
    const spy = jest.spyOn(Product, 'find');
    try {
      const { data } = await invoke(storefront.getStorefront, { params: { slug: 'river-kitchen' }, query: { brandingOnly: 'true' } });
      expect(data.restaurant.name).toBe('River Kitchen');
      expect(spy).not.toHaveBeenCalled();
    } finally { spy.mockRestore(); }
    const { data } = await invoke(storefront.getStorefront, { params: { slug: 'river-kitchen' }, query: { T: 'T01' } });
    expect(data.products).toEqual([]);
    expect(data.categories).toEqual([]);
    expect(data.table).toMatchObject({ isValid: false, totalTables: 0 });
  });

  test('unknown restaurants never return or create orders for another business', async () => {
    await expect(invoke(storefront.getStorefront, { params: { slug: 'missing-store' }, query: {} })).rejects.toMatchObject({ statusCode: 404 });
    await expect(invoke(storefront.createStorefrontOrder, { params: { slug: 'missing-store' }, body: {} })).rejects.toMatchObject({ statusCode: 404 });
  });

  test('saved branding and hours reach the public API even when profile history exists', async () => {
    await Business.updateOne({ _id: business._id }, { $push: { profileHistory: { changedFields: ['name'] } } });
    await invoke(profile.updateSettings, {
      user: { _id: business.ownerId },
      body: { storefrontOnline: false, storefrontThemeColor: 0xFF2244AA, storefrontThemeColorEnd: null,
        openingTime: '08:00 AM', storefrontBanners: [{ id: 'new', headline: 'Today only', isActive: true }] },
    });
    const { data } = await invoke(storefront.getStorefront, { params: { slug: 'river-kitchen' }, query: {} });
    expect(data.isOnline).toBe(false);
    expect(data.themeColorHex).toBe(0xFF2244AA);
    expect(data.restaurant.openingTime).toBe('08:00 AM');
    expect(data.banners.map(b => b.headline)).toEqual(['Today only']);
  });
});
