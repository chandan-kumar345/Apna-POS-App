// Read-only by default. Never run automatically at server startup.
require('../config/env');
const mongoose = require('mongoose');
const { migrate } = require('../services/entitlementMigration');

async function main() {
  const args = process.argv.slice(2);
  if (args.some((arg) => !['--apply', '--dry-run'].includes(arg)) || args.includes('--apply') && args.includes('--dry-run')) {
    throw new Error('Usage: node src/scripts/migrateEntitlements.js [--dry-run | --apply]');
  }
  if (!process.env.MONGODB_URI) throw new Error('Set MONGODB_URI to the reviewed migration target');
  await mongoose.connect(process.env.MONGODB_URI, { autoIndex: false });
  try { console.log(JSON.stringify(await migrate(mongoose.connection.db, { apply: args.includes('--apply') }), null, 2)); }
  finally { await mongoose.disconnect(); }
}
if (require.main === module) main().catch((error) => { console.error(error.message); process.exitCode = 1; });
