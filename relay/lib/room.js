'use strict';

const { log, warn } = require('./logger');
const fcm = require('./fcm');

/**
 * Summarize a message data object for push notification body text.
 * Extracts content/text/message field, truncates to 50 chars.
 * @param {*} data
 * @returns {string}
 */
function _summarizeMessage(data) {
  if (!data || typeof data !== 'object') return 'Task completed';
  const content = data.content || data.text || data.message || '';
  const text = typeof content === 'string' ? content : JSON.stringify(content);
  return text.length > 50 ? text.substring(0, 50) + '...' : text || 'Task completed';
}

/**
 * Manages rooms keyed by token. Each room holds at most one desktop and one mobile WebSocket.
 * When the mobile is offline, desktop messages are queued and flushed on reconnect.
 */
class RoomManager {
  constructor() {
    // Map<string, { desktop: WebSocket|null, mobile: WebSocket|null, offlineQueue: Array, fcmToken: string|null }>
    this._rooms = new Map();

    // Periodic cleanup of expired queue entries (24-hour TTL).
    this._cleanupInterval = setInterval(() => this._cleanupExpiredQueues(), 3600_000); // every hour
  }

  /**
   * Add a WebSocket to a room under the given role.
   * If role is "desktop" and a desktop already exists, close the old one with code 4002.
   * If role is "mobile" and there are queued offline messages, flush them.
   *
   * @param {string} token - Room token.
   * @param {string} role - "desktop" or "mobile".
   * @param {WebSocket} ws - The WebSocket connection.
   */
  join(token, role, ws) {
    if (!this._rooms.has(token)) {
      this._rooms.set(token, { desktop: null, mobile: null, offlineQueue: [], fcmToken: null });
    }

    const room = this._rooms.get(token);

    if (role === 'desktop') {
      // If a desktop already exists, replace it.
      if (room.desktop) {
        const oldDesktop = room.desktop;
        // Clear the slot first to prevent _onDisconnect from deleting the room
        // when the old desktop's close handler fires synchronously.
        room.desktop = null;
        try {
          oldDesktop.close(4002, 'replaced by new connection');
        } catch (_) {
          // May already be closed.
        }
        log(`Room [${token}]: existing desktop replaced (code 4002)`);
      }
      room.desktop = ws;
      // Ensure the room is in the map -- it may have been deleted by the
      // old desktop's close handler firing synchronously during replacement.
      if (!this._rooms.has(token)) {
        this._rooms.set(token, room);
      }
    } else {
      // mobile
      room.mobile = ws;

      // Flush any queued offline messages when mobile reconnects.
      if (room.offlineQueue.length > 0) {
        this._flushOfflineQueue(room);
      }
    }

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

  /**
   * Forward a message from one side to the other.
   * @param {WebSocket} from - Sender.
   * @param {WebSocket|null} to - Recipient.
   * @param {string} data - Raw message data.
   */
  _forward(from, to, data) {
    if (to && to.readyState === 1) {
      try {
        to.send(data);
      } catch (err) {
        warn(`Forward error: ${err.message}`);
      }
    }
  }

  /**
   * Handle incoming message from a client.
   * - ping/pong: log and consume (do not forward).
   * - fcm:register (from mobile): store FCM token, do not forward.
   * - desktop -> mobile: forward if online, queue if offline, trigger push for task-complete events.
   * - Everything else: forward to the paired client.
   *
   * @param {string} token
   * @param {string} role - "desktop" or "mobile"
   * @param {WebSocket} ws
   * @param {Buffer|string} data
   */
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

    // Consume heartbeat messages.
    if (event === 'ping' || event === 'pong') {
      log(`Room [${token}]: ${role} heartbeat (${event}), consumed`);
      return;
    }

    // Get the room.
    const room = this._rooms.get(token);
    if (!room) return;

    // Handle FCM token registration from mobile (do not forward).
    if (role === 'mobile' && event === 'fcm:register') {
      room.fcmToken = parsed.data?.token || null;
      log(`Room [${token}]: FCM token registered (${room.fcmToken ? room.fcmToken.substring(0, 8) + '...' : 'null'})`);
      return;
    }

    if (role === 'desktop') {
      const mobileOnline = room.mobile && room.mobile.readyState === 1;

      if (mobileOnline) {
        // Mobile is connected -- forward normally.
        this._forward(ws, room.mobile, raw);
      } else {
        // Mobile is offline -- queue the message.
        room.offlineQueue.push({ raw, timestamp: Date.now() });
        log(`Room [${token}]: message queued (offline queue size: ${room.offlineQueue.length})`);

        // Send push notification for task completion events.
        if (room.fcmToken && (event === 'stream:done' || event === 'message:assistant' || event === 'stream:error')) {
          const channelId = event === 'stream:error' ? 'error' : 'task_complete';
          fcm.sendPushNotification(room.fcmToken, {
            title: 'wzxClaw',
            body: _summarizeMessage(parsed.data),
            channelId: channelId,
          });
        }
      }

      log(`Room [${token}]: ${role} -> ${mobileOnline ? 'mobile' : 'queued'} event=${event}`);
    } else {
      // Mobile -> desktop: forward normally.
      const target = room.desktop;
      this._forward(ws, target, raw);
      log(`Room [${token}]: ${role} -> desktop event=${event}`);
    }
  }

  /**
   * Handle client disconnection.
   * - Remove the client from its room slot.
   * - Notify the other side with a system message.
   * - Delete the room if both sides are null and queue is empty.
   *
   * @param {string} token
   * @param {string} role
   * @param {WebSocket} ws
   */
  _onDisconnect(token, role, ws) {
    const room = this._rooms.get(token);
    if (!room) return;

    // Clear the slot only if this ws is still the current occupant.
    if (role === 'desktop' && room.desktop === ws) {
      room.desktop = null;
    } else if (role === 'mobile' && room.mobile === ws) {
      room.mobile = null;
    }

    log(`Room [${token}]: ${role} disconnected`);

    // Notify the other side.
    if (role === 'desktop' && room.mobile) {
      this._sendSystem(room.mobile, 'system:desktop_disconnected');
    } else if (role === 'mobile' && room.desktop) {
      this._sendSystem(room.desktop, 'system:mobile_disconnected');
    }

    // Clean up empty rooms (also when queue is empty and no FCM token stored).
    if (room.desktop === null && room.mobile === null && room.offlineQueue.length === 0) {
      this._rooms.delete(token);
      log(`Room [${token}]: room deleted (empty)`);
    }
  }

  /**
   * Flush all queued offline messages to the mobile client.
   * @param {{ mobile: WebSocket|null, offlineQueue: Array }} room
   */
  _flushOfflineQueue(room) {
    if (!room.mobile || room.mobile.readyState !== 1) return;
    if (room.offlineQueue.length === 0) return;

    const count = room.offlineQueue.length;
    log(`Flushing ${count} offline messages`);

    for (const msg of room.offlineQueue) {
      try {
        room.mobile.send(msg.raw);
      } catch (err) {
        warn(`Flush error: ${err.message}`);
      }
    }

    room.offlineQueue = [];
  }

  /**
   * Periodically clean up expired queue entries (24-hour TTL).
   */
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

  /**
   * Send a system event to a WebSocket if it is open.
   * @param {WebSocket} ws
   * @param {string} event
   */
  _sendSystem(ws, event) {
    if (ws && ws.readyState === 1) {
      try {
        ws.send(JSON.stringify({ event }));
      } catch (_) {
        // Ignore send errors on closing sockets.
      }
    }
  }

  /**
   * Return the number of active rooms.
   * @returns {number}
   */
  getRoomCount() {
    return this._rooms.size;
  }

  /**
   * Close all connections and clear all rooms. Used for graceful shutdown.
   */
  closeAll() {
    clearInterval(this._cleanupInterval);
    for (const [token, room] of this._rooms) {
      if (room.desktop) {
        try { room.desktop.close(1001, 'server shutdown'); } catch (_) {}
      }
      if (room.mobile) {
        try { room.mobile.close(1001, 'server shutdown'); } catch (_) {}
      }
    }
    this._rooms.clear();
  }
}

module.exports = { RoomManager };
