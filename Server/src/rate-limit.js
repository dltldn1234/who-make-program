export class SlidingWindowRateLimiter {
  #limit;
  #windowMilliseconds;
  #requests = new Map();

  constructor(limit, windowMilliseconds = 60_000) {
    this.#limit = limit;
    this.#windowMilliseconds = windowMilliseconds;
  }

  consume(key, now = Date.now()) {
    const cutoff = now - this.#windowMilliseconds;
    const active = (this.#requests.get(key) ?? []).filter(timestamp => timestamp > cutoff);
    if (active.length >= this.#limit) {
      const retryAfterMilliseconds = active[0] + this.#windowMilliseconds - now;
      return { allowed: false, retryAfterSeconds: Math.max(1, Math.ceil(retryAfterMilliseconds / 1000)) };
    }
    active.push(now);
    this.#requests.set(key, active);
    return { allowed: true, remaining: this.#limit - active.length };
  }
}
