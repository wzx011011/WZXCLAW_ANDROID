'use strict';

const { WebSocketServer } = require('ws');
const http = require('http');
const { URL } = require('url');
const auth = require('./lib/auth');
const { RoomManager } = require('./lib/room');
const { log, warn, error } = require('./lib/logger');

// -- Configuration --
const PORT = parseInt(process.env.PORT, 10) || 8080;

// -- Initialize auth module --
auth.init();

// -- Room manager --
const roomManager = new RoomManager();

// -- Create HTTP server (needed for ws to attach) --
const server = http.createServer((req, res) => {
  // Health check endpoint.
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', rooms: roomManager.getRoomCount() }));
    return;
  }
  res.writeHead(404);
  res.end('Not Found');
});

// -- WebSocket server --
const wss = new WebSocketServer({ server });

wss.on('connection', (ws, req) => {
  // Parse query params from the upgrade request URL.
  const reqUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const token = reqUrl.searchParams.get('token') || '';
  const role = reqUrl.searchParams.get('role') || 'mobile';

  // Authenticate.
  const result = auth.authenticate(token);
  if (!result.ok) {
    log(`Connection rejected: ${result.reason} (url=${req.url})`);
    ws.close(4001, result.reason);
    return;
  }

  log(`Client connected: role=${role}, token=${token.substring(0, 4)}***`);

  // Join the room.
  roomManager.join(token, role, ws);
});

// -- Periodic status logging --
const statusInterval = setInterval(() => {
  log(`Status: ${roomManager.getRoomCount()} active room(s)`);
}, 60_000);

// -- Graceful shutdown --
function shutdown(signal) {
  log(`Received ${signal}, shutting down gracefully...`);
  clearInterval(statusInterval);
  roomManager.closeAll();
  wss.close(() => {
    server.close(() => {
      log('Server closed');
      process.exit(0);
    });
  });

  // Force exit after 5 seconds if graceful shutdown stalls.
  setTimeout(() => {
    error('Forced shutdown after timeout');
    process.exit(1);
  }, 5000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// -- Start server --
server.listen(PORT, () => {
  log(`Relay server listening on port ${PORT}`);
});

// Export for testing.
module.exports = { server, wss, roomManager };
