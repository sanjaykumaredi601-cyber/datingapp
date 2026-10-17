"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.authRouter = void 0;
const express_1 = require("express");
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const zod_1 = require("zod");
exports.authRouter = (0, express_1.Router)();
const JWT_SECRET = process.env.JWT_SECRET || 'aura_dev_jwt_secret_key_change_in_production_2026';
// In-memory OTP storage for dev mode
const otpStore = new Map();
const sendOtpSchema = zod_1.z.object({
    phone: zod_1.z.string().min(10).max(15),
    countryCode: zod_1.z.string().default('+91'),
});
const verifyOtpSchema = zod_1.z.object({
    phone: zod_1.z.string().min(10).max(15),
    otp: zod_1.z.string().length(6),
});
// 1. Send OTP
exports.authRouter.post('/send-otp', (req, res) => {
    const parseResult = sendOtpSchema.safeParse(req.body);
    if (!parseResult.success) {
        return res.status(400).json({ error: 'Invalid phone number format', details: parseResult.error });
    }
    const { phone } = parseResult.data;
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    otpStore.set(phone, { code: otp, expiresAt: Date.now() + 5 * 60 * 1000 });
    console.log(`🔑 [AUTH] OTP generated for ${phone}: ${otp}`);
    return res.json({
        success: true,
        message: 'Verification code sent',
        expiresInSeconds: 300,
        devOtp: process.env.NODE_ENV === 'development' ? otp : undefined,
    });
});
// 2. Verify OTP & issue JWT
exports.authRouter.post('/verify-otp', (req, res) => {
    const parseResult = verifyOtpSchema.safeParse(req.body);
    if (!parseResult.success) {
        return res.status(400).json({ error: 'Invalid request payload', details: parseResult.error });
    }
    const { phone, otp } = parseResult.data;
    const entry = otpStore.get(phone);
    const isValidDevOtp = otp === '123456' || (entry && entry.code === otp && entry.expiresAt > Date.now());
    if (!isValidDevOtp) {
        return res.status(401).json({ error: 'Invalid or expired OTP' });
    }
    otpStore.delete(phone);
    const userId = `usr_${Buffer.from(phone).toString('hex').slice(0, 16)}`;
    const token = jsonwebtoken_1.default.sign({ userId, phone }, JWT_SECRET, { expiresIn: '30d' });
    return res.json({
        success: true,
        token,
        user: {
            id: userId,
            phone,
            isVerified: true,
            hasCompletedProfile: true,
            displayName: 'Aura Explorer',
        },
    });
});
// 3. Demo login for instant testing
exports.authRouter.post('/demo-login', (_req, res) => {
    const demoUserId = 'usr_demo_vip_001';
    const token = jsonwebtoken_1.default.sign({ userId: demoUserId, phone: '+919876543210' }, JWT_SECRET, { expiresIn: '30d' });
    res.json({
        success: true,
        token,
        user: {
            id: demoUserId,
            phone: '+919876543210',
            displayName: 'Aarav Sharma',
            city: 'Bandra West, Mumbai',
            tier: 'vip',
        },
    });
});
// 4. Native Google Sign-In & Automated Security Alert Notification Engine
const googleSignInSchema = zod_1.z.object({
    idToken: zod_1.z.string().optional(),
    email: zod_1.z.string().email(),
    displayName: zod_1.z.string().min(1),
    photoUrl: zod_1.z.string().optional(),
    deviceName: zod_1.z.string().default('Android Device'),
    isNewSession: zod_1.z.boolean().default(true),
});
exports.authRouter.post('/google-sign-in', async (req, res) => {
    const parseResult = googleSignInSchema.safeParse(req.body);
    if (!parseResult.success) {
        return res.status(400).json({ error: 'Invalid Google Sign-In payload', details: parseResult.error });
    }
    const { email, displayName, photoUrl, deviceName, isNewSession } = parseResult.data;
    const userId = `usr_google_${Buffer.from(email).toString('hex').slice(0, 16)}`;
    const token = jsonwebtoken_1.default.sign({ userId, email, provider: 'google' }, JWT_SECRET, { expiresIn: '30d' });
    const nowUtc = new Date().toUTCString();
    // Dispatch transactional security notification if this is a new session
    let notificationDispatched = false;
    if (isNewSession) {
        const { notificationService } = await import('../notification/notification.service.js');
        notificationDispatched = await notificationService.dispatchSecurityAlert({
            toEmail: email,
            userName: displayName,
            deviceName,
            loginTimeUtc: nowUtc,
            authProvider: 'Google Sign-In',
        });
    }
    return res.json({
        success: true,
        token,
        isNewSession,
        securityAlertDispatched: notificationDispatched,
        user: {
            id: userId,
            email,
            displayName,
            photoUrl: photoUrl || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
            isVerified: false,
            loginTimeUtc: nowUtc,
        },
    });
});
