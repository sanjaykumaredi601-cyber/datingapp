"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createRateLimiter = createRateLimiter;
const ipRequestMap = new Map();
/**
 * Enterprise Sliding Window Rate Limiter
 * @param windowMs Time window in milliseconds (default: 60s)
 * @param maxRequests Maximum requests per IP per window (default: 120)
 */
function createRateLimiter(windowMs = 60000, maxRequests = 120) {
    return (req, res, next) => {
        const ip = req.ip || req.socket.remoteAddress || '127.0.0.1';
        const now = Date.now();
        const entry = ipRequestMap.get(ip);
        if (!entry || now > entry.resetAt) {
            ipRequestMap.set(ip, {
                count: 1,
                resetAt: now + windowMs,
            });
            return next();
        }
        if (entry.count >= maxRequests) {
            const retryAfterSeconds = Math.ceil((entry.resetAt - now) / 1000);
            res.setHeader('Retry-After', retryAfterSeconds);
            return res.status(429).json({
                error: 'Too Many Requests',
                message: `Rate limit exceeded. Try again in ${retryAfterSeconds} seconds.`,
            });
        }
        entry.count++;
        next();
    };
}
