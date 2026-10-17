import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

export const authRouter = Router();
const JWT_SECRET = process.env.JWT_SECRET || 'aura_dev_jwt_secret_key_change_in_production_2026';

// In-memory OTP storage for dev mode
const otpStore = new Map<string, { code: string; expiresAt: number }>();

const sendOtpSchema = z.object({
  phone: z.string().min(10).max(15),
  countryCode: z.string().default('+91'),
});

const verifyOtpSchema = z.object({
  phone: z.string().min(10).max(15),
  otp: z.string().length(6),
});

// 1. Send OTP
authRouter.post('/send-otp', (req: Request, res: Response): any => {
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
authRouter.post('/verify-otp', (req: Request, res: Response): any => {
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
  const token = jwt.sign({ userId, phone }, JWT_SECRET, { expiresIn: '30d' });

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
authRouter.post('/demo-login', (_req: Request, res: Response) => {
  const demoUserId = 'usr_demo_vip_001';
  const token = jwt.sign({ userId: demoUserId, phone: '+919876543210' }, JWT_SECRET, { expiresIn: '30d' });

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
const googleSignInSchema = z.object({
  idToken: z.string().optional(),
  email: z.string().email(),
  displayName: z.string().min(1),
  photoUrl: z.string().optional(),
  deviceName: z.string().default('Android Device'),
  isNewSession: z.boolean().default(true),
});

authRouter.post('/google-sign-in', async (req: Request, res: Response): Promise<any> => {
  const parseResult = googleSignInSchema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({ error: 'Invalid Google Sign-In payload', details: parseResult.error });
  }

  const { email, displayName, photoUrl, deviceName, isNewSession } = parseResult.data;
  const userId = `usr_google_${Buffer.from(email).toString('hex').slice(0, 16)}`;
  const token = jwt.sign({ userId, email, provider: 'google' }, JWT_SECRET, { expiresIn: '30d' });

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

