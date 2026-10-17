"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.io = exports.server = exports.app = void 0;
const express_1 = __importDefault(require("express"));
const http_1 = __importDefault(require("http"));
const socket_io_1 = require("socket.io");
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const morgan_1 = __importDefault(require("morgan"));
const dotenv_1 = __importDefault(require("dotenv"));
const path_1 = __importDefault(require("path"));
const db_js_1 = require("./config/db.js");
const auth_routes_js_1 = require("./services/auth/auth.routes.js");
const location_routes_js_1 = require("./services/location/location.routes.js");
const user_routes_js_1 = require("./services/user/user.routes.js");
const support_routes_js_1 = require("./services/support/support.routes.js");
const upload_routes_js_1 = require("./services/upload/upload.routes.js");
const translation_routes_js_1 = require("./services/translation/translation.routes.js");
const chat_socket_js_1 = require("./services/chat/chat.socket.js");
const rateLimiter_js_1 = require("./middleware/rateLimiter.js");
dotenv_1.default.config();
const app = (0, express_1.default)();
exports.app = app;
const server = http_1.default.createServer(app);
exports.server = server;
const io = new socket_io_1.Server(server, {
    cors: {
        origin: '*',
        methods: ['GET', 'POST'],
    },
});
exports.io = io;
const PORT = process.env.PORT || 3000;
// Middleware
app.use((0, helmet_1.default)({ contentSecurityPolicy: false }));
app.use((0, cors_1.default)());
app.use((0, morgan_1.default)('dev'));
app.use(express_1.default.json({ limit: '15mb' }));
app.use(express_1.default.urlencoded({ extended: true, limit: '15mb' }));
app.use('/uploads', express_1.default.static(path_1.default.join(process.cwd(), 'uploads')));
app.use('/api', (0, rateLimiter_js_1.createRateLimiter)(60000, 150)); // Global 150 req/min rate limit per IP
// Health Check
app.get('/health', (_req, res) => {
    res.json({
        status: 'healthy',
        service: 'Aura Core API & Realtime Gateway',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
    });
});
// Mount Routes
app.use('/api/auth', auth_routes_js_1.authRouter);
app.use('/api/location', location_routes_js_1.locationRouter);
app.use('/api/user', user_routes_js_1.userRouter);
app.use('/api/support', support_routes_js_1.supportRouter);
app.use('/api/upload', upload_routes_js_1.uploadRouter);
app.use('/api/translation', translation_routes_js_1.translationRouter);
// Global Error Handler
app.use((err, _req, res, _next) => {
    console.error('Unhandled server error:', err);
    res.status(500).json({ error: 'Internal server error', message: err.message });
});
// Setup Realtime Chat WebSockets
(0, chat_socket_js_1.setupChatSocket)(io);
// Start Server
server.listen(PORT, async () => {
    console.log(`\n==================================================`);
    console.log(`🌌 AURA BACKEND SERVER RUNNING`);
    console.log(`📡 HTTP API:        http://localhost:${PORT}`);
    console.log(`⚡ WebSocket / WSS: ws://localhost:${PORT}`);
    console.log(`❤️  Health Check:    http://localhost:${PORT}/health`);
    console.log(`==================================================\n`);
    await (0, db_js_1.checkDatabaseConnection)();
});
