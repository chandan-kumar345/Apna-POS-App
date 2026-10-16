const mongoose = require('mongoose');
require('dotenv').config();

async function run() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/apna_pos');
  const db = mongoose.connection.db;

  const b1Id = new mongoose.Types.ObjectId('6abe430203f46a99a8b7654c'); // Shri Sai Cafe
  const b2Id = new mongoose.Types.ObjectId('6ac231b100d8b9e342094661'); // Delhi Chai Cafe / terminal 2

  console.log('--- 1. BACKUP DATA ---');
  const b2Orders = await db.collection('orders').find({ businessId: b2Id }).toArray();
  const b2Sales = await db.collection('sales').find({ businessId: b2Id }).toArray();
  const b2PrintLogs = await db.collection('printlogs').find({ businessId: b2Id }).toArray();
  const b2Customers = await db.collection('customers').find({ businessId: b2Id }).toArray();

  if (b2Orders.length > 0) {
    await db.collection('orders_backup_pre_migration').deleteMany({ businessId: b2Id });
    await db.collection('orders_backup_pre_migration').insertMany(b2Orders);
  }
  if (b2Sales.length > 0) {
    await db.collection('sales_backup_pre_migration').deleteMany({ businessId: b2Id });
    await db.collection('sales_backup_pre_migration').insertMany(b2Sales);
  }
  if (b2PrintLogs.length > 0) {
    await db.collection('printlogs_backup_pre_migration').deleteMany({ businessId: b2Id });
    await db.collection('printlogs_backup_pre_migration').insertMany(b2PrintLogs);
  }
  console.log(`Backed up ${b2Orders.length} orders, ${b2Sales.length} sales, ${b2PrintLogs.length} printlogs.`);

  console.log('\n--- 2. MIGRATE ORDERS, SALES, PRINTLOGS TO SHRI SAI CAFE ---');
  const ordersResult = await db.collection('orders').updateMany(
    { businessId: b2Id },
    { $set: { businessId: b1Id } }
  );
  console.log(`Migrated ${ordersResult.modifiedCount} orders to businessId ${b1Id}`);

  const salesResult = await db.collection('sales').updateMany(
    { businessId: b2Id },
    { $set: { businessId: b1Id } }
  );
  console.log(`Migrated ${salesResult.modifiedCount} sales to businessId ${b1Id}`);

  const printlogsResult = await db.collection('printlogs').updateMany(
    { businessId: b2Id },
    { $set: { businessId: b1Id } }
  );
  console.log(`Migrated ${printlogsResult.modifiedCount} printlogs to businessId ${b1Id}`);

  // Migrate customers
  for (const cust of b2Customers) {
    const existing = await db.collection('customers').findOne({ businessId: b1Id, phone: cust.phone });
    if (!existing) {
      await db.collection('customers').updateOne(
        { _id: cust._id },
        { $set: { businessId: b1Id } }
      );
    }
  }

  // Link user delhi@gmail.com to b1Id
  await db.collection('users').updateOne(
    { email: 'delhi@gmail.com' },
    { $set: { businessId: b1Id } }
  );
  console.log('Linked user delhi@gmail.com to Shri Sai Cafe businessId.');

  console.log('\n--- 3. VERIFY DASHBOARD AGGREGATION FOR SHRI SAI CAFE ---');
  const dashboardService = require('../services/dashboardService');

  const summary = await dashboardService.getSummary(b1Id.toString(), { period: 'alltime' });
  console.log('All-time Summary:', summary);

  const orderTypes = await dashboardService.getOrderTypes(b1Id.toString(), { period: 'alltime' });
  console.log('Order Types:', orderTypes);

  // Verification as of Oct 13:
  const oct13Summary = await dashboardService.getSummary(b1Id.toString(), {
    startDate: '2020-01-01T00:00:00.000Z',
    endDate: '2026-10-13T21:49:00.000Z'
  });
  console.log('Oct 13 9:49 PM Summary:', oct13Summary);

  const oct13OrderTypes = await dashboardService.getOrderTypes(b1Id.toString(), {
    startDate: '2020-01-01T00:00:00.000Z',
    endDate: '2026-10-13T21:49:00.000Z'
  });
  console.log('Oct 13 9:49 PM Order Types:', oct13OrderTypes);

  await mongoose.disconnect();
}

run().catch(console.error);
