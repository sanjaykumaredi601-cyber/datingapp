"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.pool = void 0;
exports.checkDatabaseConnection = checkDatabaseConnection;
exports.isDatabaseLive = isDatabaseLive;
const pg_1 = __importDefault(require("pg"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const { Pool } = pg_1.default;
exports.pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    user: process.env.DB_USER || 'aura_user',
    password: process.env.DB_PASSWORD || 'aura_secret',
    database: process.env.DB_NAME || 'aura_db',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 3000,
});
let isDbConnected = false;
async function checkDatabaseConnection() {
    try {
        const client = await exports.pool.connect();
        const result = await client.query('SELECT NOW()');
        client.release();
        isDbConnected = true;
        console.log('✅ PostgreSQL + PostGIS connected at:', result.rows[0].now);
        return true;
    }
    catch (err) {
        isDbConnected = false;
        console.warn('⚠️ PostgreSQL not reachable (' + err.message + '). Running in in-memory / mock development mode.');
        console.warn('💡 Tip: Run `docker compose up -d` to launch PostgreSQL + PostGIS + Redis.');
        return false;
    }
}
function isDatabaseLive() {
    return isDbConnected;
}
