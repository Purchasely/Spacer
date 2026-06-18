//
//  RateLimiter.swift
//  Spacer
//
//  Client-side self-throttle. NASA's shared key 429s easily, so we cap the steady
//  request rate while still allowing a burst for normal browsing, and honour a
//  global cooldown after any 429. Image-byte loads bypass this — they hit
//  non-metered archive hosts directly (see ImageLoader).
//
//  Implemented as a token bucket: `burst` tokens are available immediately (so a
//  handful of screens load instantly), refilling at `requestsPerMinute`. While a
//  429 cooldown is active, `acquire()` THROWS `.rateLimited` so callers fail fast
//  and serve cache — never hang waiting out a 30s cooldown. An actor, safe to share.
//

import Foundation

actor RateLimiter {
    private let capacity: Double
    private let refillPerSecond: Double
    private var tokens: Double
    private var lastRefill: Date
    private var cooldownUntil: Date?

    /// - Parameters:
    ///   - requestsPerMinute: steady-state refill rate.
    ///   - burst: tokens available immediately (normal browsing never waits).
    init(requestsPerMinute: Double = 60, burst: Double = 15) {
        self.capacity = burst
        self.refillPerSecond = max(0.1, requestsPerMinute / 60.0)
        self.tokens = burst
        self.lastRefill = Date()
    }

    /// Reserves a slot. Returns seconds to wait before firing (0 when a token is
    /// available). Throws `.rateLimited` if a 429 cooldown is active, so the caller
    /// fails fast instead of blocking.
    func acquire() throws -> TimeInterval {
        let now = Date()
        if let cooldownUntil, cooldownUntil > now {
            throw APIError.rateLimited(retryAfter: cooldownUntil.timeIntervalSince(now))
        }
        tokens = min(capacity, tokens + now.timeIntervalSince(lastRefill) * refillPerSecond)
        lastRefill = now

        if tokens >= 1 {
            tokens -= 1
            return 0
        }
        let needed = 1 - tokens
        tokens = 0
        return needed / refillPerSecond
    }

    /// Records a 429. Subsequent `acquire()` calls fail fast until the cooldown ends.
    func recordRateLimited(retryAfter: TimeInterval?) {
        let cooldown = min(retryAfter ?? 30, 60)
        cooldownUntil = Date().addingTimeInterval(cooldown)
    }

    /// Clears the cooldown (e.g. after a confirmed success).
    func clearCooldown() {
        cooldownUntil = nil
    }
}
