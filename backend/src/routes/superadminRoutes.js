const express = require('express');
const superadminController = require('../controllers/superadminController');
const superAdminMiddleware = require('../middleware/superAdminMiddleware');

const router = express.Router();

// 1. Super Admin Authentication (Restricted to Master Owner)
router.post('/login', (req, res, next) => superadminController.login(req, res, next));

// 2. Super Admin Protected Routes
router.use(superAdminMiddleware);

// Profile
router.get('/me', (req, res, next) => superadminController.getMe(req, res, next));

// Analytics & Dashboard Stats
router.get('/stats', (req, res, next) => superadminController.getStats(req, res, next));

// User Management (CRUD, Status, Subscription, Reset Password)
router.get('/users', (req, res, next) => superadminController.getUsers(req, res, next));
router.post('/users', (req, res, next) => superadminController.createUser(req, res, next));
router.get('/users/:id', (req, res, next) => superadminController.getUserById(req, res, next));
router.get('/users/:id/sales', (req, res, next) => superadminController.getUserSales(req, res, next));
router.put('/users/:id', (req, res, next) => superadminController.updateUser(req, res, next));
router.patch('/users/:id/status', (req, res, next) => superadminController.updateUserStatus(req, res, next));
router.patch('/users/:id/subscription', (req, res, next) => superadminController.updateUserSubscription(req, res, next));
router.patch('/users/:id/reset-password', (req, res, next) => superadminController.resetUserPassword(req, res, next));
router.delete('/users/:id', (req, res, next) => superadminController.deleteUser(req, res, next));

// Database Overview & Exploration
router.get('/database/overview', (req, res, next) => superadminController.getDatabaseOverview(req, res, next));
router.get('/database/collection/:collectionName', (req, res, next) => superadminController.getCollectionDocuments(req, res, next));

// Super Admin Order Management & Purge
router.delete('/orders/:idOrNumber', (req, res, next) => superadminController.deleteOrder(req, res, next));
router.post('/orders/delete', (req, res, next) => superadminController.deleteOrder(req, res, next));

// Subscription Leads Management
router.get('/leads', (req, res, next) => superadminController.getLeads(req, res, next));
router.patch('/leads/:id', (req, res, next) => superadminController.updateLead(req, res, next));
router.delete('/leads/:id', (req, res, next) => superadminController.deleteLead(req, res, next));

module.exports = router;
