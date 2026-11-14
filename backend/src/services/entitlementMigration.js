const controls = ['isSubscription', 'subscriptionExpiresAt', 'isChotuAiActive'];
const has = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const date = (value) => value instanceof Date && Number.isFinite(value.getTime());

function planBusiness(business, legacySources = []) {
  const review = [];
  const set = {};
  for (const key of ['isSubscription', 'isChotuAiActive']) {
    if (has(business, key) && typeof business[key] !== 'boolean') review.push(`Invalid canonical ${key}`);
  }
  if (has(business, 'subscriptionExpiresAt') && business.subscriptionExpiresAt !== null && !date(business.subscriptionExpiresAt)) {
    review.push('Canonical expiry is not a BSON Date');
  }
  const candidates = [];
  for (const source of legacySources.filter(Boolean)) {
    const flags = ['isSubscriptionActive', 'isActive', 'isSubscribed'].filter((key) => has(source, key)).map((key) => source[key]);
    const meaningful = flags.includes(true) || source.expiresAt != null || ['active', 'trial', 'expired', 'cancelled'].includes(source.status);
    if (!meaningful) continue; // Ignore automatically seeded starter placeholders.
    if (flags.some((value) => typeof value !== 'boolean') || new Set(flags).size > 1) {
      review.push('Legacy flags are invalid or disagree'); continue;
    }
    const enabled = flags.length ? flags[0] : ['active', 'trial'].includes(source.status);
    if (enabled && ['inactive', 'cancelled'].includes(source.status)) review.push('Legacy status contradicts enabled flag');
    if (!date(source.expiresAt)) { review.push('Legacy entitlement has no reliable finite BSON expiry'); continue; }
    candidates.push({ enabled, expiry: source.expiresAt });
  }
  const signatures = new Set(candidates.map((item) => `${item.enabled}:${item.expiry.getTime()}`));
  if (signatures.size > 1) review.push('Legacy sources disagree on entitlement or expiry');
  const candidate = candidates[0];
  if (candidate && has(business, 'isSubscription') && !has(business, 'subscriptionExpiresAt')
    && business.isSubscription !== candidate.enabled) review.push('Partial canonical flag contradicts legacy entitlement');
  if (candidate && has(business, 'subscriptionExpiresAt') && !has(business, 'isSubscription')
    && (!date(business.subscriptionExpiresAt) || business.subscriptionExpiresAt.getTime() !== candidate.expiry.getTime())) {
    review.push('Partial canonical expiry contradicts legacy entitlement');
  }
  const needsSubscriptionMapping = !has(business, 'isSubscription') || !has(business, 'subscriptionExpiresAt');
  if (needsSubscriptionMapping && !review.length) {
    if (!has(business, 'isSubscription')) set.isSubscription = candidate?.enabled ?? false;
    if (!has(business, 'subscriptionExpiresAt')) set.subscriptionExpiresAt = candidate?.expiry ?? null;
    if (!candidate) review.push('No reliable legacy entitlement; default disabled, no expiry invented');
  }
  if (!has(business, 'isChotuAiActive')) {
    set.isChotuAiActive = false;
    if (business.orderSettings?.enableChotuVoice === true) review.push('Voice preference was user-editable; administrator must approve AI entitlement');
  }
  const conflict = review.some((reason) => !reason.startsWith('No reliable') && !reason.startsWith('Voice preference'));
  return { businessId: String(business._id), set: conflict ? {} : set, review,
    filter: { _id: business._id, ...Object.fromEntries(controls.map((key) => [key, !has(business, key) ? { $exists: false }
      : business[key] === null ? { $eq: null, $exists: true } : business[key]])) } };
}

async function migrate(db, { apply = false } = {}) {
  const businesses = await db.collection('businesses').find({}).toArray();
  const report = [];
  for (const business of businesses) {
    const owner = await db.collection('users').findOne({ _id: business.ownerId });
    const ownersBusinesses = businesses.filter((item) => String(item.ownerId) === String(business.ownerId));
    const uniqueOwner = ownersBusinesses.length === 1 && (!owner?.businessId || String(owner.businessId) === String(business._id));
    const history = await db.collection('premiumsubscriptions').find({
      staffId: null, targetType: { $in: ['business', 'user', null] },
      $or: [
        { businessId: business._id },
        ...(uniqueOwner ? [{ businessId: null, userId: business.ownerId },
          ...(owner?.email ? [{ businessId: null, userId: null, userEmail: owner.email }] : [])] : []),
      ],
    }).toArray();
    const sources = [business.subscription, ...history];
    if (uniqueOwner) sources.push(owner?.subscription);
    const plan = planBusiness(business, sources);
    if (apply && Object.keys(plan.set).length) {
      const result = await db.collection('businesses').updateOne(plan.filter, { $set: plan.set });
      plan.applied = result.modifiedCount === 1;
      if (!plan.applied) plan.review.push('Concurrent canonical change; skipped');
    }
    delete plan.filter;
    report.push(plan);
  }
  return { mode: apply ? 'apply' : 'dry-run', businesses: report.length, records: report };
}

module.exports = { planBusiness, migrate };
