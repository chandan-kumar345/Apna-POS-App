const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const Business = require('../src/models/Business');
const Customer = require('../src/models/Customer');
const Order = require('../src/models/Order');
const Sale = require('../src/models/Sale');
const crmService = require('../src/services/crmService');
const dashboardService = require('../src/services/dashboardService');
const salesService = require('../src/services/salesService');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/apna_pos';

async function runTests() {
  console.log('--- Running CRM, Dashboard & Sales Report Tests ---');
  await mongoose.connect(MONGODB_URI);
  console.log('Connected to MongoDB');

  let testBusiness = await Business.findOne();
  if (!testBusiness) {
    testBusiness = await Business.create({
      name: 'CRM Test Cafe',
      phone: '9876543210',
      email: 'crm_test@example.com',
    });
  }
  const businessId = testBusiness._id;

  // 1. Test CRM Lead Creation
  console.log('\n1. Testing CRM Create Lead...');
  const newLead = await crmService.createLead(businessId, {
    name: 'Sanjeev Kumar Thakur',
    phone: '9198687750910',
    email: 'sanjeev@example.com',
    source: 'Dine In',
    stage: 'New Lead',
    status: 'New Lead',
    tags: ['New Lead', 'VIP'],
    notes: 'Likes window table',
  });
  console.log('Lead created:', newLead.name, newLead.phone, newLead.stage);

  // 2. Test CRM Stage Update
  console.log('\n2. Testing CRM Stage Update...');
  const updatedStageLead = await crmService.updateLeadStage(businessId, newLead._id, 'Prospect');
  console.log('Stage updated to:', updatedStageLead.stage);

  // 3. Test CRM Follow-up Setting
  console.log('\n3. Testing CRM Set Follow-up...');
  const followupDate = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000);
  const updatedFollowupLead = await crmService.setFollowup(businessId, newLead._id, {
    followupDate,
    followupNotes: 'Call to confirm weekend anniversary reservation',
  });
  console.log('Follow-up set for:', updatedFollowupLead.followupDate, updatedFollowupLead.followupNotes);

  // 4. Test CRM Leads Query & Filtering
  console.log('\n4. Testing CRM Leads Query & Filtering...');
  const leadsResult = await crmService.getLeads(businessId, {
    page: 1,
    limit: 10,
    search: 'Sanjeev',
  });
  console.log('Leads found matching "Sanjeev":', leadsResult.leads.length, 'Total:', leadsResult.pagination.total);
  console.log('CRM Stats:', leadsResult.stats);

  // 5. Test CRM Like & Star Toggle
  console.log('\n5. Testing CRM Like & Star Toggle...');
  const liked = await crmService.toggleLike(businessId, newLead._id);
  const starred = await crmService.toggleStar(businessId, newLead._id);
  console.log('isLiked:', liked.isLiked, 'isStarred:', starred.isStarred);

  // 6. Test Dashboard Overview Single-Call Aggregation
  console.log('\n6. Testing Dashboard Overview Single-Call Aggregation...');
  const dashboardOverview = await dashboardService.getOverview(businessId, { period: 'All Time' });
  console.log('Dashboard Overview Summary:', {
    totalRevenue: dashboardOverview.summary.revenue || dashboardOverview.summary.totalRevenue,
    totalOrders: dashboardOverview.summary.totalOrders,
    productSalesCount: dashboardOverview.productSales.length,
    newCustomers: dashboardOverview.customers.newCustomers.length,
    returningCustomers: dashboardOverview.customers.returningCustomers.length,
    dineInOrders: dashboardOverview.orderTypes.dineIn.count,
    totalPaymentAmount: dashboardOverview.paymentMethods.totalAmount,
  });

  // 7. Test Sales Report Unified Aggregation
  console.log('\n7. Testing Sales Report Unified Aggregation...');
  const salesReport = await salesService.getSalesReport(businessId, { period: 'All Time' });
  console.log('Sales Report Summary:', {
    totalRevenue: salesReport.summary.totalRevenue,
    totalOrders: salesReport.summary.totalOrders,
    totalItems: salesReport.summary.totalItems,
    paymentModesCount: salesReport.paymentModes.length,
    topProductsCount: salesReport.topProducts.length,
  });

  console.log('\n🎉 ALL BACKEND CRM, DASHBOARD & SALES REPORT TESTS PASSED!');
  await mongoose.disconnect();
}

runTests().catch((err) => {
  console.error('Test Failed:', err);
  process.exit(1);
});
