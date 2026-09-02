const express = require('express');
const authRoutes = require('./authRoutes');
const onboardingRoutes = require('./onboardingRoutes');
const profileRoutes = require('./profileRoutes');
const productRoutes = require('./productRoutes');
const orderRoutes = require('./orderRoutes');
const salesRoutes = require('./salesRoutes');
const dashboardRoutes = require('./dashboardRoutes');
const tableRoutes = require('./tableRoutes');
const customerRoutes = require('./customerRoutes');
const inventoryRoutes = require('./inventoryRoutes');
const uploadRoutes = require('./uploadRoutes');
const cartRoutes = require('./cartRoutes');
const paymentMethodRoutes = require('./paymentMethodRoutes');
const extraRoutes = require('./extraRoutes');
const paymentRoutes = require('./paymentRoutes');
const printLogRoutes = require('./printLogRoutes');
const loyaltyRoutes = require('./loyaltyRoutes');
const crmRoutes = require('./crmRoutes');
const notificationRoutes = require('./notificationRoutes');
const subscriptionRoutes = require('./subscriptionRoutes');

const router = express.Router();

// Health check endpoint
router.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

router.use('/auth', authRoutes);
router.use('/onboarding', onboardingRoutes);
router.use('/profile', profileRoutes);
router.use('/products', productRoutes);
router.use('/orders', orderRoutes);
router.use('/generateposorder', orderRoutes);
router.use('/generatePosOrder', orderRoutes);
router.use('/sales', salesRoutes);
router.use('/dashboard', dashboardRoutes);
router.use('/tables', tableRoutes);
router.use('/customers', customerRoutes);
router.use('/crm', crmRoutes);
router.use('/inventory', inventoryRoutes);
router.use('/upload', uploadRoutes);
router.use('/cart', cartRoutes);
router.use('/payment-methods', paymentMethodRoutes);
router.use('/extras', extraRoutes);
router.use('/payments', paymentRoutes);
router.use('/print-logs', printLogRoutes);
router.use('/printlogs', printLogRoutes);
router.use('/loyalty', loyaltyRoutes);
router.use('/notifications', notificationRoutes);
router.use('/subscription', subscriptionRoutes);
router.use('/subscriptions', subscriptionRoutes);

module.exports = router;
