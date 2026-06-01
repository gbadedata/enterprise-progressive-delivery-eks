const test = require("node:test");
const assert = require("node:assert");

test("basic arithmetic sanity check", () => {
  assert.strictEqual(1 + 1, 2);
});
