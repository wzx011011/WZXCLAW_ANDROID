'use strict';

const admin = require('firebase-admin');
const { log, warn } = require('./logger');

let fcmApp = null;

/**
 * Initialize the Firebase Admin SDK.
 * Reads service account from FCM_SERVICE_ACCOUNT_PATH env var (defaults to ./fcm-service-account.json).
 * Safe to call multiple times -- no-op if already initialized.
 */
function init() {
  if (fcmApp) return;
  try {
    const serviceAccountPath = process.env.FCM_SERVICE_ACCOUNT_PATH || './fcm-service-account.json';
    const serviceAccount = require(serviceAccountPath);
    fcmApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    log('FCM initialized');
  } catch (err) {
    warn(`FCM init failed (push notifications disabled): ${err.message}`);
    // fcmApp stays null -- all sendPushNotification calls become no-ops.
  }
}

/**
 * Send a push notification via FCM HTTP v1 API.
 * Uses data-only message so flutter_local_notifications handles display.
 *
 * @param {string} fcmToken - Device FCM registration token.
 * @param {object} payload
 * @param {string} payload.title - Notification title (e.g., "wzxClaw")
 * @param {string} payload.body - Notification body text
 * @param {string} [payload.channelId='task_complete'] - Android notification channel ID
 * @returns {Promise<boolean>} true if sent, false if skipped/failed
 */
async function sendPushNotification(fcmToken, { title, body, channelId = 'task_complete' }) {
  if (!fcmToken || !fcmApp) return false;
  try {
    const message = {
      data: {
        title: title,
        body: body,
        channel: channelId,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: channelId,
        },
      },
      token: fcmToken,
    };
    await admin.messaging().send(message);
    log(`FCM push sent to ${fcmToken.substring(0, 8)}...`);
    return true;
  } catch (err) {
    warn(`FCM push failed: ${err.message}`);
    return false;
  }
}

module.exports = { init, sendPushNotification };
