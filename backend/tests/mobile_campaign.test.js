const mongoose = require('mongoose');
const request = require('supertest');
const app = require('../src/app');
const User = require('../src/models/User');
const Business = require('../src/models/Business');
const Product = require('../src/models/Product');
const Campaign = require('../src/models/Campaign');
const Coupon = require('../src/models/Coupon');
const AudienceGroup = require('../src/models/AudienceGroup');
const service = require('../src/services/mobileCampaignService');
const transport = require('../src/services/mobileCampaignTransport');
const campaigns = require('../src/services/campaignService');
const coupons = require('../src/services/couponService');
const cron = require('../src/services/cronService');
const wallet = require('../src/services/walletService');
const storage = require('../src/utils/storageService');
const tokens = require('../src/services/tokenService');
require('./setup');

const oid = () => new mongoose.Types.ObjectId();
let businessId, owner, token, key, form;
beforeEach(async () => {
  businessId = oid(); key = String(oid());
  owner = await User.create({ businessId, email: 'campaign@example.test', passwordHash: 'test-hash', role: 'owner' });
  await Business.create({ _id: businessId, ownerId: owner._id, profile: { companyName: 'Test cafe' }, isSubscription: true, subscriptionExpiresAt: new Date(Date.now() + 8e8) });
  token = tokens.generateAccessToken(owner);
  const group = await AudienceGroup.create({ businessId, srNo: 1, name: 'Loyal customers', numbers: [
    { name: 'Rahul', phone: '9876543210' }, { name: 'Duplicate', phone: '+91 9876543210' },
  ] });
  await Product.create([{ businessId, productId: 'pizza', name: 'Margherita', category: 'Pizza', price: 200 },
    { businessId, productId: 'bread', name: 'Garlic bread', category: 'Sides', price: 80 }]);
  form = { revision: 0, title: 'Weekend Pizza Offer', body: 'Hi {{name}}, enjoy the weekend.', category: 'MARKETING', channel: 'softcode_shared',
    groupId: String(group._id), rewardType: 'percentage', discountAmount: 20, minimumOrder: 499, maximumDiscount: 150,
    couponCode: 'weekend20', expiryAt: new Date(Date.now() + 4e8).toISOString(), orderTypes: ['takeaway','delivery'],
    actions: [{ type: 'URL', text: 'Order now', value: 'https://example.test/menu' },
      { type: 'PHONE_NUMBER', text: 'Call store', value: '+919876543210' }, { type: 'QUICK_REPLY', text: 'Interested' }] };
  jest.spyOn(transport, 'account').mockResolvedValue({});
  jest.spyOn(transport, 'approval').mockResolvedValue('APPROVED');
  jest.spyOn(transport, 'send').mockResolvedValue('provider-receipt');
  await wallet.getOrCreateWallet(businessId);
});
afterEach(() => jest.restoreAllMocks());
const save = (payload = form) => service.save(businessId, key, payload);
const launch = (extra = {}) => service.launch(businessId, key, { revision:1, confirmedOptIn: true,
  groupId:form.groupId,confirmedCount:1,...extra }, owner._id);
async function approve() {
  await service.submit(businessId,key,{revision:1});
  await cron.processCampaignReviewsJob();
}
const api = '/api/v1/campaigns/mobile';
const validate = (payload = {}) => coupons.validateCoupon(businessId, { code: 'WEEKEND20', subtotal: 1000, orderType: 'takeaway', ...payload });

test('performance counts actual POS and storefront orders once and excludes cancellations, refunds and other outlets', async () => {
  await save(); await approve(); await launch(); await cron.processScheduledCampaignsJob();
  const Order = require('../src/models/Order');
  const base = { businessId, couponCode:'WEEKEND20', subtotal:500, totalAmount:400, orderType:'takeaway' };
  await Order.create([
    {...base,orderNumber:'POS-1'}, {...base,orderNumber:'OFF',status:'cancelled'},
    {...base,orderNumber:'REF',paymentStatus:'refunded'}, {...base,orderNumber:'OTHER',businessId:oid()},
  ]);
  const payload = {businessId:String(businessId),orderNumber:'WEB-1', idempotencyKey:'web-1',couponCode:'weekend20',
    discountAmount:100,subtotal:500,totalAmount:400, orderType:'delivery',items:[{name:'Pizza',productId:'pizza',price:500,quantity:1}]};
  const url = '/api/v1/storefront/'+businessId+'/order';
  await request(app).post(url).send(payload).expect(201);
  await request(app).post(url).send(payload).expect(201);
  const data = await service.performance(businessId,key);
  expect(data.stats).toMatchObject({couponOrders:2,couponRevenue:800});
});

test('follow-up quotes deduplicate numbers and groups, queue once, and retain earlier receipts', async () => {
  await save(); await approve(); await launch(); await cron.processScheduledCampaignsJob();
  const first = { requestId:String(oid()), mode:'new',groupId:form.groupId,phones:['9898989898','+919898989898'],
    confirmedOptIn:true,confirmedCount:2 };
  expect(await service.followUp(businessId,key,{...first,preview:true},owner._id)).toMatchObject({count:2});
  await service.followUp(businessId,key,first,owner._id);
  await service.followUp(businessId,key,first,owner._id);
  expect(transport.send).toHaveBeenCalledTimes(1);
  transport.send.mockRejectedValueOnce(new Error('unreachable'));
  await cron.processScheduledCampaignsJob();
  const retry = {...first,requestId:String(oid()),mode:'failed',confirmedCount:1};
  expect(await service.followUp(businessId,key,{...retry,preview:true},owner._id)).toMatchObject({count:1});
  await service.followUp(businessId,key,retry,owner._id);
  await cron.processScheduledCampaignsJob();
  expect(transport.send).toHaveBeenCalledTimes(4);
  const c = await Campaign.findById(key);
  expect(c.audience.recipients.map(r => r.status)).toEqual(['sent','failed','sent','sent']);
  expect(c.cost.spentSoFar).toBeCloseTo(4.24);
});

test('image upload uses the authenticated restaurant folder and returns its public URL', async () => {
  const bytes = Buffer.from([255,216,255,217]);
  const store = jest.spyOn(storage,'uploadImage').mockResolvedValue('https://images.example.test/campaign.jpg');
  const upload = () => request(app).post('/api/v1/upload/image?folder=campaigns');
  await upload().attach('image',bytes,{filename:'campaign.jpg',contentType:'image/jpeg'}).expect(401);
  await upload().set('Authorization','Bearer '+token).attach('image',bytes,{filename:'campaign.jpg',contentType:'image/jpeg'}).expect(201);
  expect(store).toHaveBeenCalledTimes(1);
  expect(store).toHaveBeenCalledWith(bytes,'campaign.jpg','image/jpeg','campaigns/'+businessId);
});

test('authenticated HTTP draft, group options, revisions and search are business scoped', async () => {
  expect((await request(app).get(api)).status).toBe(401);
  const req = (r) => r.set('Authorization', 'Bearer ' + token);
  const options = await req(request(app).get(api + '/options')).expect(200);
  expect(options.body.data.groups[0]).toMatchObject({ name: 'Loyal customers', count: 1 });
  expect(options.body.data.products).toHaveLength(2);
  const created = await req(request(app).put(api + '/' + key)).send({ revision: 0, orderTypes: [], category: 'AUTHENTICATION' }).expect(200);
  expect(created.body.data).toMatchObject({ status: 'draft', template: { category: 'AUTHENTICATION' }, mobileStudio: { revision: 1 } });
  const edited = await req(request(app).put(api + '/' + key)).send({ ...form, revision: 1 }).expect(200);
  expect(edited.body.data.couponSettings.couponCode).toBe('WEEKEND20');
  expect(edited.body.data.template.actions[1].value).toBe('+919876543210');
  expect(await Coupon.countDocuments()).toBe(0);
  await req(request(app).put(api + '/' + key)).send({ ...form, revision: 1 }).expect(409);
  const found = await req(request(app).get(api).query({ search: 'Pizza' })).expect(200);
  expect(found.body.data.total).toBe(1);
  expect(found.body.data.campaigns[0].audience.recipients).toBeUndefined();
  expect((await service.dashboard(oid(),{})).total).toBe(0);
  expect(transport.send).not.toHaveBeenCalled();
});

test('queue uses provider approval, a single wallet debit and actual monotonically updated receipts', async () => {
  await save();
  await expect(launch()).rejects.toThrow(/approval/);
  const sendReview = () => request(app).post(api+'/'+key+'/submit').set('Authorization','Bearer '+token).send({revision:1}).expect(200);
  await Promise.all([sendReview(),sendReview()]);
  transport.approval.mockResolvedValueOnce('PENDING');
  await cron.processCampaignReviewsJob();
  expect(transport.send).not.toHaveBeenCalled();
  let c = await Campaign.findById(key);
  expect(c.template.metaStatus).toBe('PENDING');
  expect(await Coupon.countDocuments()).toBe(0);
  await Campaign.updateOne({ _id:key }, { $set: { 'mobileStudio.nextCheckAt': new Date(0) } });
  await Promise.all([cron.processCampaignReviewsJob(),cron.processCampaignReviewsJob()]);
  expect((await Campaign.findById(key)).status).toBe('approved');
  await cron.processScheduledCampaignsJob();
  expect(transport.send).not.toHaveBeenCalled();
  expect((await wallet.getOrCreateWallet(businessId)).balance).toBe(100);
  expect(await Coupon.countDocuments()).toBe(0);
  await expect(launch({confirmedOptIn:false})).rejects.toThrow(/opted in/);
  await Promise.all([launch(),launch()]);
  await Promise.all([cron.processScheduledCampaignsJob(),cron.processScheduledCampaignsJob()]);
  c = await Campaign.findById(key);
  expect(c.status).toBe('completed');
  expect(c.stats).toMatchObject({ messagesSent:1, delivered:0, read:0 });
  expect(transport.send).toHaveBeenCalledTimes(1);
  const coupon = await Coupon.findOne({ campaignId: key });
  expect(coupon.endDate.toISOString()).toBe(form.expiryAt);
  expect(await validate()).toMatchObject({ valid:true, discountAmount:150 });
  expect((await validate({orderType:'dineIn'})).valid).toBe(false);
  for (const status of ['read','delivered','read']) await campaigns.processWebhookStatusUpdate({messageId:'provider-receipt',status});
  expect((await Campaign.findById(key)).stats).toMatchObject({ messagesSent:1, delivered:1, read:1 });
  expect((await wallet.getOrCreateWallet(businessId)).balance).toBeCloseTo(98.94);
});

test('last failed receipt updates a completed campaign and keeps the provider reason', async () => {
  await save();
  await approve();
  await launch();
  await cron.processScheduledCampaignsJob();
  await campaigns.processWebhookStatusUpdate({messageId:'provider-receipt', status:'failed',
    errors:[{code:130429, message:'Request failed', error_data:{details:'Rate limit hit'}}]});
  const c = await Campaign.findById(key);
  expect(c.status).toBe('failed');
  expect(c.stats.failed).toBe(1);
  expect(c.audience.recipients[0].error).toBe('Rate limit hit (WhatsApp code 130429)');
  expect(c.mobileStudio.rateLimitedUntil.getTime()).toBeGreaterThan(Date.now());
  const followUp = { requestId:String(oid()), mode:'new',groupId:form.groupId,
    confirmedOptIn:true,confirmedCount:1 };
  await service.followUp(businessId,key,followUp,owner._id);
  await cron.processScheduledCampaignsJob();
  expect(transport.send).toHaveBeenCalledTimes(1);
  const paused = await Campaign.findById(key);
  expect(paused.status).toBe('scheduled');
  expect(paused.audience.recipients[1].status).toBe('pending');
  await Campaign.updateOne({_id:key},{$set:{'mobileStudio.rateLimitedUntil':new Date(0),'mobileStudio.nextCheckAt':new Date(0)}});
  await cron.processScheduledCampaignsJob();
  expect(transport.send).toHaveBeenCalledTimes(2);
  expect((await wallet.getOrCreateWallet(businessId)).balance).toBeCloseTo(97.88);
});

test.each([
  ['flat_discount',{discountAmount:100},[],100],
  ['free_gift',{giftItem:'bread',giftQty:2},[{productId:'bread',quantity:3,price:80}],160],
  ['bogo',{buyItem:'pizza',buyQty:2,giftItem:'bread',giftQty:1},[{productId:'pizza',quantity:2,price:200},{productId:'bread',quantity:1,price:80}],80],
  ['bogo',{buyItem:'pizza',buyQty:1,giftItem:'pizza',giftQty:1},[{productId:'pizza',quantity:3,price:200}],200],
  ['promotional',{headline:'Music night',offerDetails:'Live music from 7 PM',terms:'Dine-in only'},[],0],
])('publishes the configured %s reward',async (rewardType,fields,cartItems,discountAmount) => {
  await save({...form,rewardType,...fields});
  await approve();
  await launch(); await cron.processScheduledCampaignsJob();
  if (rewardType === 'promotional') {
    expect(await Coupon.countDocuments()).toBe(0);
  } else {
    expect(await validate({cartItems})).toMatchObject({valid:true,discountAmount});
    if (['free_gift','bogo'].includes(rewardType)) expect((await validate({cartItems:[{productId:'pizza',quantity:1,price:200}]})).valid).toBe(false);
  }
});

test('scheduled delivery waits for exact time and produces no success on provider failure',async () => {
  const at = new Date(Date.now()+3.6e6);
  await save(form); await approve(); await launch({scheduleMode:'later',sendAt:at.toISOString()});
  await cron.processScheduledCampaignsJob();
  let c = await Campaign.findById(key);
  expect(c.mobileStudio.nextCheckAt).toEqual(at);
  expect(c.status).toBe('scheduled');
  expect(transport.send).not.toHaveBeenCalled();
  await Campaign.updateOne({_id:key},{$set:{'schedule.scheduledAt':new Date(0),'mobileStudio.nextCheckAt':new Date(0)}});
  transport.send.mockRejectedValue(new Error('Provider refused'));
  await cron.processScheduledCampaignsJob();
  c = await Campaign.findById(key);
  expect(c.status).toBe('failed');
  expect(c.stats).toMatchObject({messagesSent:0,delivered:0,read:0,failed:1});
  expect((await validate()).valid).toBe(false);
});

test('invalid reward values, foreign menu items, auth broadcasts and invalid schedule cannot launch',async () => {
  await expect(save({...form,discountAmount:101})).rejects.toThrow();
  await expect(save({...form,rewardType:'free_gift',giftItem:'foreign-item'})).rejects.toThrow(/menu item/);
  await save({...form,category:'AUTHENTICATION'});
  await approve();
  await expect(launch()).rejects.toThrow(/verification/);
  key=String(oid()); await save({...form,couponCode:'OTHER'}); await approve();
  await expect(launch({scheduleMode:'later',sendAt:form.expiryAt})).rejects.toThrow(/Schedule/);
  expect(transport.send).not.toHaveBeenCalled();
});

test('recovery does not replay a recipient whose send was already claimed',async () => {
  await save(); await approve(); await launch();
  await Campaign.updateOne({_id:key},{$set:{'audience.recipients.0.status':'sending'}});
  await cron.processScheduledCampaignsJob();
  expect(transport.send).not.toHaveBeenCalled();
  expect((await Campaign.findById(key)).stats.failed).toBe(1);
});

test('a rejected template returns to the editor and a revised approval still waits for Send', async () => {
  await save();
  transport.approval.mockResolvedValueOnce('REJECTED');
  await approve();
  const rejected = await Campaign.findById(key);
  expect(rejected).toMatchObject({ status:'draft', template:{metaStatus:'REJECTED'} });
  await expect(launch()).rejects.toThrow(/approval/);
  await save({...form, revision:1, body:'Hi {{name}}, your weekend offer is ready.'});
  await service.submit(businessId,key,{revision:2});
  await cron.processCampaignReviewsJob();
  await cron.processScheduledCampaignsJob();
  expect((await Campaign.findById(key)).template.metaTemplateName).toBe('apna_'+key+'_2');
  expect(transport.send).not.toHaveBeenCalled();
  const early = await request(app).post('/api/v1/coupons/validate').set('Authorization','Bearer '+token)
    .send({code:form.couponCode,subtotal:1000}).expect(200);
  expect(early.body.data).toMatchObject({valid:false,campaignManaged:true});
});

test('a template Meta disables after approval cannot reach customers at dispatch', async () => {
  await save();
  await approve();
  await launch();
  transport.approval.mockResolvedValueOnce('DISABLED');

  await cron.processScheduledCampaignsJob();

  expect(transport.send).not.toHaveBeenCalled();
  const campaign = await Campaign.findById(key);
  expect(campaign.status).toBe('draft');
  expect(campaign.mobileStudio.sendAuthorizedAt).toBeNull();
  expect(await Coupon.countDocuments({ campaignId: key })).toBe(0);
  expect((await wallet.getOrCreateWallet(businessId)).balance).toBe(100);
});
