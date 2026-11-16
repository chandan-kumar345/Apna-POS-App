const { spawn } = require('child_process');
const path = require('path');
const ApiError = require('../../utils/ApiError');

const script = path.resolve(__dirname, '../../../python/chotu_agent/agent.py');
const ACTIONS = new Set([
  'add_items', 'remove_item', 'set_quantity', 'send_kot', 'generate_bill',
  'settle_cash', 'settle_payment', 'clear_draft', 'view_order',
]);

function enabled() {
  return process.env.CHOTU_AGENT_ENABLED !== 'false';
}

function invoke(payload, health = false) {
  return new Promise((resolve, reject) => {
    const executable = process.env.CHOTU_PYTHON_BIN || (process.platform === 'win32' ? 'python' : 'python3');
    const child = spawn(executable, [script, ...(health ? ['--health'] : [])], {
      shell: false,
      windowsHide: true,
      env: {
        PATH: process.env.PATH,
        SystemRoot: process.env.SystemRoot,
        WINDIR: process.env.WINDIR,
        PYTHONIOENCODING: 'utf-8',
      },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    let stdout = '';
    let settled = false;
    const finish = (error, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (error) reject(error); else resolve(value);
    };
    const unavailable = () => new ApiError(503, 'Chotu Python planner unavailable. Check CHOTU_PYTHON_BIN and Python 3.11+.', 'CHOTU_RUNTIME_UNAVAILABLE');
    const timer = setTimeout(() => {
      child.kill();
      finish(unavailable());
    }, 5000);
    child.on('error', () => finish(unavailable()));
    child.stdin.on('error', () => finish(unavailable()));
    child.stdout.setEncoding('utf8');
    child.stderr.on('data', () => {});
    child.stdout.on('data', (data) => {
      stdout += data;
      if (Buffer.byteLength(stdout) > 65536) {
        child.kill();
        finish(unavailable());
      }
    });
    child.on('close', (code) => {
      if (code !== 0) return finish(unavailable());
      try {
        const output = JSON.parse(stdout);
        if (!health && (!Array.isArray(output.actions) || output.actions.some((action) => !ACTIONS.has(action)))) {
          return finish(unavailable());
        }
        finish(null, output);
      } catch (_) {
        finish(unavailable());
      }
    });
    child.stdin.end(health ? '' : JSON.stringify(payload));
  });
}

module.exports = {
  enabled,
  async health() {
    if (!enabled()) return { enabled: false, available: false };
    try {
      return { enabled: true, ...(await invoke(null, true)) };
    } catch (_) {
      return { enabled: true, available: false };
    }
  },
  async plan(command, context) {
    if (!enabled()) throw new ApiError(503, 'Chotu automation agent is disabled.', 'CHOTU_AGENT_DISABLED');
    return invoke({ command, context });
  },
};
