import express, { Request, Response, NextFunction } from 'express';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import path from 'path';
import { checkDatabaseConnection } from './config/db.js';
import { authRouter } from './services/auth/auth.routes.js';
import { locationRouter } from './services/location/location.routes.js';
import { userRouter } from './services/user/user.routes.js';
import { supportRouter } from './services/support/support.routes.js';
import { uploadRouter } from './services/upload/upload.routes.js';
import { translationRouter } from './services/translation/translation.routes.js';
import { setupChatSocket } from './services/chat/chat.socket.js';
import { createRateLimiter } from './middleware/rateLimiter.js';

dotenv.config();

const app = express();
const server = http.createServer(app);

const io = new SocketIOServer(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors());
app.use(morgan('dev'));
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));
app.use('/api', createRateLimiter(60000, 150)); // Global 150 req/min rate limit per IP

// Health Check
app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'Aura Core API & Realtime Gateway',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// Mount Routes
app.use('/api/auth', authRouter);
app.use('/api/location', locationRouter);
app.use('/api/user', userRouter);
app.use('/api/support', supportRouter);
app.use('/api/upload', uploadRouter);
app.use('/api/translation', translationRouter);

// Global Error Handler
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Unhandled server error:', err);
  res.status(500).json({ error: 'Internal server error', message: err.message });
});

// Setup Realtime Chat WebSockets
setupChatSocket(io);

// Start Server
server.listen(PORT, async () => {
  console.log(`\n==================================================`);
  console.log(`🌌 AURA BACKEND SERVER RUNNING`);
  console.log(`📡 HTTP API:        http://localhost:${PORT}`);
  console.log(`⚡ WebSocket / WSS: ws://localhost:${PORT}`);
  console.log(`❤️  Health Check:    http://localhost:${PORT}/health`);
  console.log(`==================================================\n`);

  await checkDatabaseConnection();
});

export { app, server, io };
