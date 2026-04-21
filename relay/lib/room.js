'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { log, warn } = require('./logger');

const DATA_DIR = path.join(__dirname, '..', 'data');
const QUEUE_FILE = path.join(DATA_DIR, 'offline-queues.json');

/**
 * Manages rooms keyed by token. Each room holds at most one desktop and
 * multiple mobile WebSockets. When all mobiles are offline, desktop messages
 * are queued and flushed on reconnect.
 */
class RoomManager {
  constructor() {
    // Map<string, { desktop: WebSocket|null, mobiles: Set<WebSocket>, offlineQueue: Array }>
    this._rooms = new Map();

    // Periodic cleanup of expired queue entries (24-hour TTL).
    this._cleanupInterval = setInterval(() => this._cleanupExpiredQueues(), 3600_000); // every hour

    // Server-side WebSocket ping to detect dead TCP connections.
    this._healthCheckInterval = setInterval(() => this._healthCheck(), 30_000); // every 30s

    // Restore persisted offline queues from disk.
    this._loadQueues();
  }

  // ── Queue Persistence ────────────────────────────────────────────

  _loadQueues() {
    try {
      if (!fs.existsSync(QUEUE_FILE)) return;
      const raw = fs.readFileSync(QUEUE_FILE, 'utf8');
      const data = JSON.parse(raw);
      if (typeof data !== 'object' || data === null) return;
      for (const [token, queue] of Object.entries(data)) {
        if (Array.isArray(queue) && queue.length > 0) {
          if (!this._rooms.has(token)) {
            this._rooms.set(token, { desktop: null, mobiles: new Set(), offlineQueue: queue });
          } else {
            this._rooms.get(token).offlineQueue = queue;
          }
        }
      }
      log(`Loaded persisted queues for ${Object.keys(data).length} room(s)`);
    } catch (err) {
      warn(`Failed to load persisted queues: ${err.message}`);
    }
  }

  _saveQueues() {
    try {
      const data = {};
      for (const [token, room] of this._rooms) {
        if (room.offlineQueue.length > 0) {
          data[token] = room.offlineQueue;
        }
      }
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
      }
      fs.writeFileSync(QUEUE_FILE, JSON.stringify(data, null, 2), 'utf8');
    } catch (err) {
      warn(`Failed to persist queues: ${err.message}`);
    }
  }

  // ── Join / Leave ─────────────────────────────────────────────────

  join(token, role, ws) {
    if (!this._rooms.has(token)) {
      this._rooms.set(token, { desktop: null, mobiles: new Set(), offlineQueue: [] });
    }

    const room = this._rooms.get(token);

    if (role === 'desktop') {
      // If a desktop already exists, replace it.
      if (room.desktop) {
        const oldDesktop = room.desktop;
        room.desktop = null;
        try {
          oldDesktop.close(4002, 'replaced by new connection');
        } catch (_) {}
        log(`Room [${token}]: existing desktop replaced (code 4002)`);
      }
      room.desktop = ws;
      if (!this._rooms.has(token)) {
        this._rooms.set(token, room);
      }
      // Notify all mobiles that desktop is now available.
      for (const m of room.mobiles) {
        this._sendSystem(m, 'system:desktop_connected');
      }
    } else {
      // mobile — add to set (supports multiple mobiles).
      room.mobiles.add(ws);

      // Flush any queued offline messages.
      if (room.offlineQueue.length > 0) {
        this._flushOfflineQueue(room);
      }
      // Notify desktop that a mobile is available.
      if (room.desktop && room.desktop.readyState === 1) {
        this._sendSystem(room.desktop, 'system:mobile_connected');
        this._sendSystem(ws, 'system:desktop_connected');
      }
    }

    // Assign a unique deviceId for mobile connections.
    const deviceId = role === 'mobile' ? crypto.randomUUID() : null;

    log(`Room [${token}]: ${role} joined (rooms active: ${this._rooms.size})`);

    // Wire up event handlers.
    ws.on('message', (data) => {
      this._onMessage(token, role, ws, data);
    });

    ws.on('close', () => {
      this._onDisconnect(token, role, ws);
    });

    ws.on('error', (err) => {
      warn(`Room [${token}]: ${role} error: ${err.message}`);
      this._onDisconnect(token, role, ws);
    });
  }

  // ── Message Routing ───────────────────────────────────────────────

  _forward(from, to, data) {
    if (to && to.readyState === 1) {
      try {
        to.send(data);
      } catch (err) {
        warn(`Forward error: ${err.message}`);
      }
    }
  }

  /** Broadcast data to all connected mobiles in a room. */
  _broadcastToMobiles(room, data) {
    for (const m of room.mobiles) {
      this._forward(null, m, data);
    }
  }

  _onMessage(token, role, ws, data) {
    const raw = typeof data === 'string' ? data : data.toString('utf8');

    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (_) {
      warn(`Room [${token}]: ${role} sent non-JSON message, ignoring`);
      return;
    }

    const event = parsed.event;

    // Respond to ping with pong (do not forward).
    if (event === 'ping') {
      try { ws.send(JSON.stringify({ event: 'pong' })); } catch (_) {}
      return;
    }
    // Consume pong.
    if (event === 'pong') {
      return;
    }

    const room = this._rooms.get(token);
    if (!room) return;

    if (role === 'desktop') {
      const hasMobiles = room.mobiles.size > 0;

      if (hasMobiles) {
        // Broadcast to all connected mobiles.
        this._broadcastToMobiles(room, raw);
      } else {
        // All mobiles offline — queue the message (max 500).
        room.offlineQueue.push({ raw, timestamp: Date.now() });
        if (room.offlineQueue.length > 500) {
          room.offlineQueue.shift();
        }
        log(`Room [${token}]: message queued (offline queue size: ${room.offlineQueue.length})`);
      }

      log(`Room [${token}]: ${role} -> ${hasMobiles ? 'mobiles' : 'queued'} event=${event}`);
      this._saveQueues();
    } else {
      // Mobile -> desktop: forward normally.
      this._forward(ws, room.desktop, raw);
      log(`Room [${token}]: ${role} -> desktop event=${event}`);
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────

  _onDisconnect(token, role, ws) {
    const room = this._rooms.get(token);
    if (!room) return;

    if (role === 'desktop' && room.desktop === ws) {
      room.desktop = null;
      // Clear stale session/workspace messages from offline queue.
      room.offlineQueue = room.offlineQueue.filter(msg => {
        try {
          const parsed = JSON.parse(msg.raw);
          const evt = parsed.event || '';
          return !evt.startsWith('session:') && !evt.startsWith('identity:');
        } catch (_) {
          return true;
        }
      });
      // Notify all mobiles.
      for (const m of room.mobiles) {
        this._sendSystem(m, 'system:desktop_disconnected');
      }
    } else if (role === 'mobile') {
      room.mobiles.delete(ws);
      // Only notify desktop when the LAST mobile disconnects.
      if (room.mobiles.size === 0 && room.desktop) {
        this._sendSystem(room.desktop, 'system:mobile_disconnected');
      }
    }

    log(`Room [${token}]: ${role} disconnected (mobiles remaining: ${room.mobiles.size})`);

    // Clean up empty rooms.
    if (room.desktop === null && room.mobiles.size === 0 && room.offlineQueue.length === 0) {
      this._rooms.delete(token);
      log(`Room [${token}]: room deleted (empty)`);
    }
  }

  // ── Offline Queue ─────────────────────────────────────────────────

  _flushOfflineQueue(room) {
    if (room.mobiles.size === 0) return;
    if (room.offlineQueue.length === 0) return;

    // Drain atomically.
    const queue = room.offlineQueue;
    room.offlineQueue = [];

    log(`Flushing ${queue.length} offline messages to ${room.mobiles.size} mobile(s)`);

    for (const msg of queue) {
      this._broadcastToMobiles(room, msg.raw);
    }
    this._saveQueues();
  }

  _cleanupExpiredQueues() {
    const ttl = 24 * 60 * 60 * 1000; // 24 hours
    const now = Date.now();
    for (const [token, room] of this._rooms) {
      if (room.offlineQueue.length === 0) continue;
      const before = room.offlineQueue.length;
      room.offlineQueue = room.offlineQueue.filter(msg => (now - msg.timestamp) < ttl);
      if (room.offlineQueue.length < before) {
        log(`Room [${token}]: expired ${before - room.offlineQueue.length} queued messages (24h TTL)`);
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  _sendSystem(ws, event) {
    if (ws && ws.readyState === 1) {
      try {
        ws.send(JSON.stringify({ event }));
        log(`[_sendSystem] sent ${event} to client (readyState=${ws.readyState})`);
      } catch (err) {
        log(`[_sendSystem] failed to send ${event}: ${err.message}`);
      }
    } else {
      log(`[_sendSystem] skipped ${event} — ws is ${ws ? 'readyState=' + ws.readyState : 'null'}`);
    }
  }

  getRoomCount() {
    return this._rooms.size;
  }

  _healthCheck() {
    const failures = [];
    for (const [token, room] of this._rooms) {
      if (room.desktop && room.desktop.readyState === 1) {
        try { room.desktop.ping(); } catch (_) { failures.push({ token, role: 'desktop', ws: room.desktop }); }
      }
      for (const m of room.mobiles) {
        if (m.readyState === 1) {
          try { m.ping(); } catch (_) { failures.push({ token, role: 'mobile', ws: m }); }
        }
      }
    }
    for (const { token, role, ws } of failures) {
      warn(`Room [${token}]: ${role} ping failed, triggering disconnect`);
      this._onDisconnect(token, role, ws);
    }
  }

  closeAll() {
    clearInterval(this._cleanupInterval);
    clearInterval(this._healthCheckInterval);
    this._saveQueues();
    for (const [token, room] of this._rooms) {
      if (room.desktop) {
        try { room.desktop.close(1001, 'server shutdown'); } catch (_) {}
      }
      for (const m of room.mobiles) {
        try { m.close(1001, 'server shutdown'); } catch (_) {}
      }
    }
    this._rooms.clear();
  }
}

module.exports = { RoomManager };
