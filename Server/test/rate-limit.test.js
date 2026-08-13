import assert from "node:assert/strict";
import test from "node:test";
import { SlidingWindowRateLimiter } from "../src/rate-limit.js";

test("rate limiter isolates clients and recovers after its window", () => {
  const limiter = new SlidingWindowRateLimiter(2, 1_000);
  assert.equal(limiter.consume("mac", 0).allowed, true);
  assert.equal(limiter.consume("mac", 100).allowed, true);
  assert.equal(limiter.consume("mac", 200).allowed, false);
  assert.equal(limiter.consume("phone", 200).allowed, true);
  assert.equal(limiter.consume("mac", 1_001).allowed, true);
});
