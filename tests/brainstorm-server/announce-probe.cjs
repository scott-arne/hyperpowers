// Preload for lifecycle.test.js: at the instant server.cjs prints
// server-started, record whether state/server-info already exists. The
// check runs inside the server process, synchronously with the
// announcement, so a reader's scheduling cannot hide the ordering.
const fs = require('fs');
const path = require('path');
const origLog = console.log;
console.log = function (...args) {
  const line = args.map(String).join(' ');
  if (line.includes('"type":"server-started"')) {
    let state = 'unparsed';
    try {
      const info = JSON.parse(line);
      state = fs.existsSync(path.join(info.state_dir, 'server-info')) ? 'present' : 'missing';
    } catch (e) { /* leave unparsed */ }
    process.stderr.write(`announce-probe: server-info ${state}\n`);
  }
  return origLog.apply(console, args);
};
