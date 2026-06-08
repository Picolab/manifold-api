/** Prevent tsx/node from auto-starting the test runner before bootstrap setup completes. */
process.argv = process.argv.filter(arg => arg !== "--test");
if (process.execArgv) {
  process.execArgv = process.execArgv.filter(arg => arg !== "--test");
}
