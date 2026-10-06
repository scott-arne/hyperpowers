// A test() wrapper must record a body that throws synchronously as one
// failure and keep going; server.test.js's wrapper aborted the whole run
// instead, which is how a load-sensitive assertion took every later test
// and the teardown with it.
const assert = require('assert');
const { makeTestRunner } = require('./test-runner');

(async () => {
  const lines = [];
  const { test, counts } = makeTestRunner({ log: (l) => lines.push(l) });
  await test('throws synchronously', () => { throw new Error('sync boom'); });
  await test('passes', () => Promise.resolve());
  await test('skips', () => { const e = new Error('no symlinks here'); e.skip = true; throw e; });
  assert.deepStrictEqual(counts, { passed: 1, failed: 1, skipped: 1 });
  assert.deepStrictEqual(lines, [
    '  FAIL: throws synchronously',
    '    sync boom',
    '  PASS: passes',
    '  SKIP: skips',
    '    no symlinks here',
  ]);
  console.log('--- Results: 1 passed, 0 failed ---');
})().catch((e) => {
  console.log(`  FAIL: ${e.message}`);
  console.log('--- Results: 0 passed, 1 failed ---');
  process.exitCode = 1;
});
