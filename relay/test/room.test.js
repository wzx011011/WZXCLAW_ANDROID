'use strict';

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { RoomManager } = require('../lib/room');

/**
 * Create a mock WebSocket object.
 * @returns {{ ws: object, sent: string[], closed: {code: number, reason: string}[] }}
 */
function createMockWs() {
  const sent = [];
  const closed = [];
  const listeners = {};

  const ws = {
    readyState: 1, // OPEN
    send(data) {
      sent.push(typeof data === 'string' ? data : data.toString());
    },
    close(code, reason) {
      ws.readyState = 3; // CLOSED
      closed.push({ code, reason });
      // Trigger close listeners.
      if (listeners.close) {
        listeners.close.forEach(fn => fn());
      }
    },
    on(event, fn) {
      if (!listeners[event]) listeners[event] = [];
      listeners[event].push(fn);
    },
    // Helper to simulate receiving a message.
    _receive(data) {
      if (listeners.message) {
        listeners.message.forEach(fn => fn(data));
      }
    },
    // Helper to simulate disconnect.
    _disconnect() {
      ws.readyState = 3;
      if (listeners.close) {
        listeners.close.forEach(fn => fn());
      }
    },
    // Helper to simulate error.
    _error(err) {
      if (listeners.error) {
        listeners.error.forEach(fn => fn(err));
      }
    },
  };

  return { ws, sent, closed };
}

describe('RoomManager', () => {
  let roomManager;

  beforeEach(() => {
    roomManager = new RoomManager();
  });

  it('joining a desktop creates a room with desktop slot filled', () => {
    const { ws } = createMockWs();
    roomManager.join('token-1', 'desktop', ws);
    assert.equal(roomManager.getRoomCount(), 1);
  });

  it('joining a mobile for same token pairs them', () => {
    const { ws: desktop } = createMockWs();
    const { ws: mobile } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop);
    roomManager.join('token-1', 'mobile', mobile);
    assert.equal(roomManager.getRoomCount(), 1);
  });

  it('joining a second desktop replaces the first', () => {
    const { ws: desktop1, closed: closed1 } = createMockWs();
    const { ws: desktop2 } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop1);
    roomManager.join('token-1', 'desktop', desktop2);
    assert.equal(closed1.length, 1);
    assert.equal(closed1[0].code, 4002);
    assert.equal(closed1[0].reason, 'replaced by new connection');
    assert.equal(roomManager.getRoomCount(), 1);
  });

  it('disconnecting desktop sends system:desktop_disconnected to mobile', () => {
    const { ws: desktop } = createMockWs();
    const { ws: mobile, sent: mobileSent } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop);
    roomManager.join('token-1', 'mobile', mobile);

    // Simulate desktop disconnect.
    desktop._disconnect();

    assert.equal(mobileSent.length, 1);
    const msg = JSON.parse(mobileSent[0]);
    assert.equal(msg.event, 'system:desktop_disconnected');
  });

  it('disconnecting mobile sends system:mobile_disconnected to desktop', () => {
    const { ws: desktop, sent: desktopSent } = createMockWs();
    const { ws: mobile } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop);
    roomManager.join('token-1', 'mobile', mobile);

    // Simulate mobile disconnect.
    mobile._disconnect();

    assert.equal(desktopSent.length, 1);
    const msg = JSON.parse(desktopSent[0]);
    assert.equal(msg.event, 'system:mobile_disconnected');
  });

  it('getRoomCount() reflects active rooms', () => {
    const { ws: d1 } = createMockWs();
    const { ws: m1 } = createMockWs();
    const { ws: d2 } = createMockWs();

    roomManager.join('token-1', 'desktop', d1);
    assert.equal(roomManager.getRoomCount(), 1);

    roomManager.join('token-1', 'mobile', m1);
    assert.equal(roomManager.getRoomCount(), 1);

    roomManager.join('token-2', 'desktop', d2);
    assert.equal(roomManager.getRoomCount(), 2);
  });

  it('room is deleted when both sides disconnect', () => {
    const { ws: desktop } = createMockWs();
    const { ws: mobile } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop);
    roomManager.join('token-1', 'mobile', mobile);

    desktop._disconnect();
    assert.equal(roomManager.getRoomCount(), 1);

    mobile._disconnect();
    assert.equal(roomManager.getRoomCount(), 0);
  });

  it('forwards messages from desktop to mobile', () => {
    const { ws: desktop } = createMockWs();
    const { ws: mobile, sent: mobileSent } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop);
    roomManager.join('token-1', 'mobile', mobile);

    desktop._receive(JSON.stringify({ event: 'connected', data: { status: 'ok' } }));

    assert.equal(mobileSent.length, 1);
    const msg = JSON.parse(mobileSent[0]);
    assert.equal(msg.event, 'connected');
  });

  it('forwards messages from mobile to desktop', () => {
    const { ws: desktop, sent: desktopSent } = createMockWs();
    const { ws: mobile } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop);
    roomManager.join('token-1', 'mobile', mobile);

    mobile._receive(JSON.stringify({ event: 'command:send', data: { content: 'hello' } }));

    assert.equal(desktopSent.length, 1);
    const msg = JSON.parse(desktopSent[0]);
    assert.equal(msg.event, 'command:send');
  });

  it('does not forward ping messages', () => {
    const { ws: desktop } = createMockWs();
    const { ws: mobile, sent: mobileSent } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop);
    roomManager.join('token-1', 'mobile', mobile);

    desktop._receive(JSON.stringify({ event: 'ping' }));

    assert.equal(mobileSent.length, 0);
  });

  it('does not forward pong messages', () => {
    const { ws: desktop, sent: desktopSent } = createMockWs();
    const { ws: mobile } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop);
    roomManager.join('token-1', 'mobile', mobile);

    mobile._receive(JSON.stringify({ event: 'pong' }));

    assert.equal(desktopSent.length, 0);
  });

  it('ignores non-JSON messages', () => {
    const { ws: desktop } = createMockWs();
    const { ws: mobile, sent: mobileSent } = createMockWs();
    roomManager.join('token-1', 'desktop', desktop);
    roomManager.join('token-1', 'mobile', mobile);

    // Should not throw, should not forward.
    desktop._receive('not-json');

    assert.equal(mobileSent.length, 0);
  });

  it('closeAll() closes all connections', () => {
    const { ws: d1, closed: c1 } = createMockWs();
    const { ws: m1, closed: c2 } = createMockWs();
    roomManager.join('t1', 'desktop', d1);
    roomManager.join('t1', 'mobile', m1);

    roomManager.closeAll();

    assert.equal(c1.length, 1);
    assert.equal(c2.length, 1);
    assert.equal(roomManager.getRoomCount(), 0);
  });
});
