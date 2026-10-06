'use strict';
// fn runs inside the promise chain, so a synchronous throw lands in .catch
// exactly like a rejected promise: one FAIL is recorded and the caller's loop
// continues to the next test and to its teardown. An error carrying `skip`
// records a SKIP instead.
function makeTestRunner({ log = console.log } = {}) {
  const counts = { passed: 0, failed: 0, skipped: 0 };
  function test(name, fn) {
    return Promise.resolve()
      .then(fn)
      .then(() => {
        log(`  PASS: ${name}`);
        counts.passed++;
      })
      .catch((e) => {
        if (e && e.skip) {
          log(`  SKIP: ${name}`);
          log(`    ${e.message}`);
          counts.skipped++;
          return;
        }
        log(`  FAIL: ${name}`);
        log(`    ${e && e.message}`);
        counts.failed++;
      });
  }
  return { test, counts };
}

module.exports = { makeTestRunner };
