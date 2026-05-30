import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { initDatabase } from './database.js';
import apiRouter from './api.js';
import { initWebSocket } from './websocket.js';
import { reconnectAllBots, disconnectAllBots } from './qqbot.js';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// API routes
app.use('/api', apiRouter);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Create HTTP server
const server = createServer(app);

// Initialize and start
async function start() {
  try {
    // Initialize database
    await initDatabase();
    console.log('Database initialized');

    // Initialize WebSocket server
    initWebSocket(server);

    // Start server
    server.listen(PORT, () => {
      console.log(`QQBot Backend running on port ${PORT}`);
      console.log(`API: http://localhost:${PORT}/api`);
      console.log(`WebSocket: ws://localhost:${PORT}/ws`);

      // Reconnect all bots from database
      reconnectAllBots();
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

start();

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('Shutting down...');
  disconnectAllBots();
  server.close();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('Shutting down...');
  disconnectAllBots();
  server.close();
  process.exit(0);
});
