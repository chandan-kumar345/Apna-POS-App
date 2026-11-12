// Opt-in launcher: use the normal backend with the Python order agent enabled.
require('../config/env');
process.env.CHOTU_AGENT_ENABLED = 'true';
const python = require('../services/chotu/pythonAgentBridge');

(async () => {
  const health = await python.health();
  if (!health.available) {
    console.error('Chotu requires Python 3.11+. Set CHOTU_PYTHON_BIN to its executable path.');
    process.exitCode = 1;
    return;
  }
  if (process.argv.includes('--check')) {
    console.log(JSON.stringify(health));
    return;
  }
  require('../server');
})().catch(() => {
  console.error('Unable to start Chotu. Check the backend and Python configuration.');
  process.exitCode = 1;
});
