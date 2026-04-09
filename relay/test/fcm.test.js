'use strict';

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');

describe('FCM Module', () => {
  let fcm;

  beforeEach(() => {
    // Re-require to get fresh module state for each test.
    // Clear the require cache so init() starts from scratch.
    delete require.cache[require.resolve('../lib/fcm')];
    fcm = require('../lib/fcm');
  });

  it('init() does not throw when service account file is missing', () => {
    // Should log a warning but not throw.
    assert.doesNotThrow(() => fcm.init());
  });

  it('sendPushNotification returns false with no token', async () => {
    const result = await fcm.sendPushNotification(null, { title: 'test', body: 'test' });
    assert.equal(result, false);
  });

  it('sendPushNotification returns false with empty token', async () => {
    const result = await fcm.sendPushNotification('', { title: 'test', body: 'test' });
    assert.equal(result, false);
  });

  it('sendPushNotification returns false when FCM not initialized', async () => {
    // fcmApp is null because no real service account file exists in test env.
    const result = await fcm.sendPushNotification('some-token', { title: 'test', body: 'test' });
    assert.equal(result, false);
  });
});
