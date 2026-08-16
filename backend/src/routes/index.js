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
router.use('/sales', salesRoutes);
router.use('/dashboard', dashboardRoutes);
router.use('/tables', tableRoutes);
router.use('/customers', customerRoutes);
router.use('/inventory', inventoryRoutes);
router.use('/upload', uploadRoutes);

module.exports = router;
