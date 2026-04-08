# Pitfalls Research

**Domain:** Flutter Android mobile client + NAS WebSocket relay to desktop IDE
**Researched:** 2026-04-09
**Confidence:** HIGH (critical pitfalls), MEDIUM (Chinese push notification specifics)

## Critical Pitfalls

### Pitfall 1: WebSocket Silent Stall on Android (The "Looks Connected But Dead" Problem)

**What goes wrong:**
On Android, WebSocket connections can enter a "silent stall" state where the connection object reports `open`, but no messages are sent or received. No `onClose` or `onError` event fires. The UI shows "connected" but the user gets no messages. This happens during WiFi-to-mobile network switches, when the app enters background, or when Android enters power-saving mode. It is worse on Android than iOS because Android's network stack is more aggressive about silent TCP resets.

**Why it happens:**
Android's network layer can silently drop TCP connections during network transitions (WiFi to cellular, cellular to WiFi, signal loss). The WebSocket protocol runs on TCP, and TCP keepalive timeout on mobile is typically 2 hours -- far too long for the user to wait. The `web_socket_channel` package in Flutter only exposes `onDone` and `onError` callbacks, neither of which fire for a half-open (stalled) connection. Developers who only check `WebSocket.readyState` see "open" and assume everything is fine.

**How to avoid:**
Implement an application-level heartbeat system (ping/pong) with a timeout. The client sends a `ping` every 15 seconds. The server must respond with `pong`. If no `pong` arrives within 8 seconds, treat the connection as dead and force-close it, then trigger reconnection with exponential backoff. Do NOT rely on TCP keepalive or WebSocket protocol-level ping frames -- use business-level JSON messages `{"type": "ping"}` so you can track timing and log RTT. Track `lastMessageTime` as a secondary guard: if no message of any kind arrives within 60 seconds, force reconnect.

**Warning signs:**
- Messages sent from mobile never arrive at desktop, but the connection indicator shows "connected"
- `ping` messages go out but no `pong` comes back
- Network switch log entries (WiFi to cellular) immediately before "connection works" complaints
- `lastMessageTime` exceeds 2x heartbeat interval without triggering any reconnect

**Phase to address:**
Phase 1 (WebSocket Connection Manager) -- This must be built into the connection manager from day one. Retrofitting heartbeat logic later means rewriting the entire connection lifecycle.

---

### Pitfall 2: Nginx 60-Second WebSocket Timeout Cuts Connections

**What goes wrong:**
After the WebSocket connection is idle for exactly 60 seconds, Nginx drops it. The client sees a disconnect, reconnects, and the cycle repeats. If the desktop wzxClaw is running a long AI task that takes 90 seconds between messages, the relay connection is killed before the result arrives. The user sees connection status flickering every minute during idle periods.

**Why it happens:**
Nginx's default `proxy_read_timeout` is 60 seconds. This is the time between two successive reads from the proxied server. If no data flows through the WebSocket for 60 seconds, Nginx considers the connection dead and closes it. This is a well-known issue documented in the Nginx proxy documentation. Synology DSM's built-in reverse proxy uses Nginx under the hood and inherits this default.

**How to avoid:**
Configure the Nginx reverse proxy (or Synology DSM reverse proxy custom headers) to increase WebSocket timeouts AND ensure WebSocket upgrade headers are set. The configuration should be:

```
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
proxy_connect_timeout 60s;
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

For Synology DSM 7: use Control Panel > Login Portal > Advanced > Reverse Proxy > Custom Header > WebSocket dropdown. For Nginx Proxy Manager in Docker: add these directives in the Advanced tab of the proxy host. Additionally, the application-level heartbeat from Pitfall 1 also prevents this: if the client sends a ping every 15 seconds, Nginx sees data flow and never hits the 60-second timeout.

**Warning signs:**
- WebSocket disconnects exactly at 60-second intervals during idle
- Connections survive during active chat but drop when waiting for AI responses
- Nginx access logs show 502/504 for WebSocket endpoints
- Connection recovers immediately after disconnect (auto-reconnect works, but the cycle repeats)

**Phase to address:**
Phase 1 (Infrastructure Setup) -- This must be configured before any client testing begins, otherwise every developer and tester will see constant disconnects and waste time debugging the client when the problem is server-side.

---

### Pitfall 3: FCM Does Not Work on Chinese Android Phones

**What goes wrong:**
Push notifications silently fail on Chinese Android phones (Huawei, Xiaomi, OPPO, vivo, Honor). The app sends a notification via FCM, but the phone never receives it. This affects the core feature of "receive notification when AI task completes while app is in background." The developer tests on a phone with Google Play Services (or an emulator) and everything works, but the actual user's Chinese phone never gets the notification.

**Why it happens:**
Most Android phones sold in China do not include Google Play Services, which is required for FCM. Without Google Play Services, FCM messages are not delivered. Each Chinese manufacturer (Huawei HMS, Xiaomi Mi Push, OPPO Push, vivo Push) has its own proprietary push channel with different APIs, different quotas (some limit to 1-5 messages/day for unauthenticated apps), and different integration requirements. There is no single unified standard despite the existence of the Unified Push Alliance (统一推送联盟).

**How to avoid:**
For a personal tool with a single user, the pragmatic approach is:
1. **Primary: WebSocket + Foreground Service for active sessions.** When the user is actively waiting for AI results, keep a foreground service with a persistent notification. This prevents Android from killing the connection.
2. **Fallback: Poll-based notification check.** When the app resumes from background, have it immediately check for completed tasks via an HTTP API endpoint on the relay server.
3. **If push notifications are truly needed: Integrate the specific manufacturer's push SDK for the user's phone brand.** For a single-user app, identify which phone they use and integrate only that manufacturer's SDK. The `china_push` Flutter package wraps 6 major Chinese manufacturer push channels under one API and is the simplest integration path.
4. **Do NOT rely on FCM** for Chinese Android phones. It will not work.

**Warning signs:**
- Push notifications work on emulator but not on physical Chinese phone
- FCM token registration succeeds but messages never arrive
- Background notification delivery rate near 0% on target device
- `google_play_services` availability check returns false

**Phase to address:**
Phase 2 (Push Notifications) -- The push notification architecture decision must be made before implementation. If the target device is a Chinese phone, FCM-only implementation is wasted effort. Decide early: foreground service + HTTP polling, or manufacturer-specific push SDK.

---

### Pitfall 4: Android SDK 35 Kills Background Connections in 3-5 Seconds

**What goes wrong:**
On Android targeting SDK 35 (Android 15+), the OS kills all network connections including WebSocket within 3-5 seconds of the app entering the background. The WebSocket does not gracefully close -- it just stops working. When the user returns to the app, the connection appears open but is dead (ties into Pitfall 1). Even on Android 13/14, WebSocket connections are killed approximately 20 seconds after the app goes to background.

**Why it happens:**
Android has progressively restricted background execution since Android 8 (Oreo). SDK 35 tightened this further by aggressively terminating network sockets for backgrounded apps. This is by design to save battery. Flutter's GitHub issue #164368 documents this specifically. The OS does not send a close event -- the TCP connection is simply severed from the OS side.

**How to avoid:**
1. **Accept that WebSocket dies in background.** Do not fight this. Design the architecture so that the WebSocket is for foreground real-time communication only.
2. **On app resume (`AppLifecycleState.resumed`):** Always force-close the existing connection and reconnect. Do not trust the old connection. Send a ping immediately after connecting to verify it works.
3. **Use `WidgetsBindingObserver` to detect lifecycle changes.** On `paused`, stop heartbeats. On `resumed`, reconnect with a fresh connection.
4. **For background notification delivery:** Use push notifications (see Pitfall 3) or short-interval HTTP polling on resume, NOT persistent WebSocket.
5. **Do NOT use Android foreground service just to keep WebSocket alive for a personal tool.** Foreground services require a persistent notification, user permission, and are increasingly restricted. Save this complexity for a commercial app with many users.

**Warning signs:**
- Connection dies exactly 3-5 seconds after pressing the home button on SDK 35 device
- Connection dies after ~20 seconds on Android 13/14 devices
- `onDone` or `onError` callbacks never fire after background death
- App resume shows stale data or "connected" status but no new messages arrive

**Phase to address:**
Phase 1 (Connection Manager) -- Lifecycle handling must be part of the connection manager architecture. If lifecycle is treated as an afterthought, the entire reconnection logic will need to be rewritten.

---

### Pitfall 5: No Message Queuing During Disconnection = Lost Messages

**What goes wrong:**
The user sends a programming instruction from the phone. The WebSocket is temporarily disconnected (network flicker, background transition). The message is silently lost. The user thinks the instruction was sent, but the desktop wzxClaw never received it. No error is shown. The user waits indefinitely for a response that will never come because the desktop never got the request.

**Why it happens:**
Raw WebSocket has no delivery guarantee. If `socket.send()` is called when the connection is stalled or recently disconnected, the message may be silently dropped. Unlike HTTP (which returns an error code), WebSocket `send` is fire-and-forget. Developers often do not check connection state before sending, or they check `readyState == open` which does not detect silent stalls (Pitfall 1).

**How to avoid:**
Implement a client-side send queue with the following rules:
1. If the connection is in `open` state and heartbeat is healthy, send immediately.
2. If the connection is not `open`, queue the message locally (with a max queue size, e.g., 200 messages).
3. When the connection re-establishes, flush the queue in order.
4. Each business message must have a client-generated unique ID (`cid`). The server should ACK each message. If the client does not receive an ACK within a timeout, re-send from the queue.
5. The server must be idempotent -- it should handle duplicate messages gracefully using the `cid`.

On the server side (relay), queue messages destined for disconnected clients. When the mobile client reconnects, deliver queued messages. This requires the relay server to maintain a per-session message buffer.

**Warning signs:**
- User reports "I sent a message but nothing happened"
- Messages sent during poor network conditions never arrive at the desktop
- No error feedback shown to the user when send fails
- Server logs show no record of messages the user claims to have sent

**Phase to address:**
Phase 1 (Connection Manager + Relay Server) -- Message queuing requires both client-side and server-side implementation. The relay server design must include message buffering from the start.

---

### Pitfall 6: Multiple WebSocket Instances Created by Different Pages/Widgets

**What goes wrong:**
Different pages in the Flutter app (chat page, project list page, settings page) each create their own WebSocket connection. This leads to duplicate messages (the relay server sends the same message to N connections), doubled bandwidth usage, state inconsistency across pages, and wasted battery. If one page closes its connection, the server might interpret this as the client disconnecting.

**Why it happens:**
Flutter's widget lifecycle makes it easy to create a WebSocket connection in `initState` and tear it down in `dispose`. Each page does this independently. Without a centralized connection manager, there is no coordination. This is especially common in chat apps where developers naturally want the chat page to "own" its connection.

**How to avoid:**
Use a singleton WebSocket manager (with Riverpod `Provider` or a global singleton) that:
1. Manages exactly one WebSocket connection for the entire app.
2. Broadcasts messages to all subscribers via a `StreamController.broadcast()`.
3. Is created at app startup and disposed at app shutdown, not tied to any individual page.
4. Pages subscribe to the message stream and the connection state `ValueNotifier`, but never create or close connections themselves.

**Warning signs:**
- Same message appears twice in the chat UI
- Network traffic shows duplicate WebSocket upgrade requests
- Memory usage grows as user navigates between pages
- Server logs show multiple simultaneous connections from the same mobile client

**Phase to address:**
Phase 1 (Architecture) -- The singleton connection manager pattern must be established as an architectural decision before any page-level code is written. Retrofitting a singleton after multiple pages have their own connections requires rewriting every page.

---

### Pitfall 7: Synology Reverse Proxy Does Not Configure WebSocket Headers by Default

**What goes wrong:**
The WebSocket connection fails immediately with a 400/502 error, or connects but never upgrades from HTTP to WebSocket. The `wss://5945.top/ws` endpoint returns HTTP responses instead of WebSocket frames. This happens even though HTTPS and the reverse proxy are working fine for regular HTTP traffic.

**Why it happens:**
Synology DSM's built-in reverse proxy (Nginx-based) does not automatically add WebSocket upgrade headers (`Upgrade: websocket`, `Connection: upgrade`) to reverse proxy rules. Without these headers, the HTTP connection never upgrades to WebSocket. This is documented in Synology's KB and the Home Assistant community. Many developers assume that since HTTPS works, WSS will too.

**How to avoid:**
When creating the reverse proxy rule in Synology DSM 7:
1. Go to Control Panel > Login Portal > Advanced > Reverse Proxy
2. Create the proxy host for the WebSocket endpoint
3. Go to the Custom Header tab
4. Use the "WebSocket" dropdown option (DSM 7 provides this as a preset) to automatically add the required `Upgrade` and `Connection` headers
5. Add custom Nginx directives for timeout: `proxy_read_timeout 3600s; proxy_send_timeout 3600s;`

Alternatively, if using Nginx Proxy Manager in Docker, these headers and timeouts can be configured in the proxy host's Advanced tab.

**Warning signs:**
- WebSocket connection returns HTTP 400 immediately
- Browser dev tools show no `Upgrade` header in the response
- `wss://` URL works when connecting directly to the Docker container port but fails through the reverse proxy
- Connection works on local network but fails through the public domain

**Phase to address:**
Phase 1 (Infrastructure) -- This must be verified before any client development. A simple `wscat` test from outside the network should confirm the WebSocket upgrade works through the reverse proxy.

---

### Pitfall 8: Speech-to-Text `speech_to_text` Plugin Is Not Truly Offline for Chinese

**What goes wrong:**
Voice input appears to work during development (testing on a device with Google services), but fails or has poor quality when the user's Chinese phone has no Google services or no internet. The `speech_to_text` plugin with `locale: zh_CN` returns errors, empty results, or takes extremely long to respond on the target device.

**Why it happens:**
The `speech_to_text` Flutter plugin wraps the platform's native speech recognition API. On Android, this is Google's Speech Recognition service, which:
1. Requires Google Play Services to be present (not available on most Chinese phones)
2. Works best with an internet connection (online recognition is higher quality)
3. Has limited offline language pack support for Chinese
4. Is not designed for continuous dictation -- it works best for short commands (5-30 seconds)

Even when offline Chinese language packs are available, they must be manually downloaded in Android settings > Language & Input, and the quality is significantly lower than online recognition.

**How to avoid:**
For Chinese language voice input on a personal tool:
1. **First choice: Use the device's built-in voice input method (IME).** Chinese Android phones have built-in voice input in their IME (Sogou, Baidu, Huawei, Xiaomi keyboards). When the user taps a text field and uses the IME's voice input, the IME handles all speech recognition with optimized Chinese models. No plugin needed. This is the most reliable and highest-quality approach.
2. **Second choice: Use `speech_to_text` with `zh_CN` locale, but only on devices with Google Play Services and internet.** Accept that this limits voice input capability.
3. **Third choice (if in-app voice button is required): Use a cloud speech API** (e.g., Baidu Speech, iFlytek, or Alibaba's speech service) that works in China and has excellent Chinese recognition. This requires an HTTP endpoint and API key but delivers the best Chinese recognition quality.

Do NOT build an in-app speech recognition system that depends on Google Play Services for a Chinese phone.

**Warning signs:**
- `speech_to_text` initialize fails on target device
- Recognition works in English but returns empty for Chinese
- Recognition works only when device is online
- `SpeechToText.initialize()` returns false on the target phone

**Phase to address:**
Phase 2 (Voice Input) -- Before implementing voice input, verify what speech recognition is available on the actual target device. Test `speech_to_text` initialization on the physical phone. If it fails, pivot to IME-based input or cloud API before writing any voice UI code.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `onDone => connect()` with no backoff | Fast reconnection | Reconnection storm kills server during network outage | Never |
| Token in WebSocket URL query string | Easy auth, works everywhere | Token appears in server logs, browser history, Nginx access logs | MVP only -- switch to first-message auth or header auth before any sharing |
| No message queue, fire-and-forget send | Simpler code | Messages lost during disconnection, user frustration | Never -- even a simple 50-message RAM queue is better than nothing |
| Per-page WebSocket connections | Simple page-level code | Duplicate messages, state drift, resource waste | Never |
| Skip heartbeat, trust TCP keepalive | Less code, fewer timers | Silent stall detection takes 2+ hours instead of 15 seconds | Never |
| FCM-only push notifications | Standard Flutter approach, lots of tutorials | Zero delivery on Chinese phones | Only if target device has Google Play Services |
| Skip SSL for WebSocket (use `ws://` not `wss://`) | No certificate management needed | Vulnerable to MITM, token exposure, Android blocks non-TLS on API 28+ | Never |
| Hardcode NAS IP/port in Flutter app | Quick testing | Breaks when IP changes, cannot work over WAN | Development only |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Synology DSM Reverse Proxy | Assuming HTTPS reverse proxy automatically supports WSS | Explicitly add WebSocket custom headers (Upgrade, Connection) in DSM reverse proxy settings |
| Nginx Proxy timeouts | Using default `proxy_read_timeout 60s` | Set `proxy_read_timeout 3600s` for WebSocket locations, or rely on heartbeat to generate traffic |
| `web_socket_channel` (Flutter) | Checking `readyState == open` to determine if connected | Use heartbeat timeout: if no pong within 8s of ping, connection is dead regardless of readyState |
| `speech_to_text` (Flutter) | Assuming `locale: zh_CN` works offline on all Android devices | Verify Google Play Services availability first; use IME voice input as fallback |
| Flutter App Lifecycle | Not handling `AppLifecycleState.resumed` event | On resume: force-close old connection, reconnect fresh, verify with ping |
| Docker networking (NAS) | Exposing WebSocket container port directly instead of reverse proxying | Route through reverse proxy for HTTPS/WSS and domain name access |
| FCM push on Chinese phones | Implementing FCM and assuming it works on all Android devices | Detect Google Play Services at runtime; use manufacturer-specific push or polling fallback |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Reconnection storm (no backoff) | Server CPU spikes, all clients reconnect simultaneously on network recovery | Exponential backoff with jitter: `delay = min(30s, base * 2^attempt) + random(0-500ms)` | 2+ clients on same network |
| Large message buffer on reconnect | Memory spike, UI freeze when flushing 1000+ queued messages | Cap send queue at 200 messages; discard oldest; flush with small delays | Prolonged offline period |
| Streaming chat UI rebuild on every token | UI stutters, dropped frames during fast AI streaming | Batch UI updates (e.g., add characters to buffer, rebuild every 50ms, not every message) | Long streaming responses at high token rate |
| No connection state deduplication | Multiple reconnect attempts running simultaneously | Use a connection sequence number (`_connSeq`); ignore callbacks from stale connections | Rapid network changes (WiFi off/on/off/on) |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Auth token in WebSocket URL query string (`wss://domain/ws?token=xxx`) | Token logged by Nginx, potentially leaked in browser history or referrer headers | Send token as the first message after connection, or use a custom subprotocol header; rotate tokens frequently |
| No origin validation on WebSocket server | Any website can open a WebSocket to the relay server (Cross-Site WebSocket Hijacking) | Validate Origin header on the relay server; reject connections from unknown origins |
| No authentication on relay server | Anyone who discovers the relay URL can connect and send commands to the desktop IDE | Require auth token on every WebSocket connection; validate on relay server before forwarding to desktop |
| Long-lived tokens without rotation | If a token is intercepted, attacker has permanent access | Use short-lived tokens (e.g., 24 hours); implement token refresh; invalidate old tokens on the relay server |
| No TLS on WebSocket (`ws://` instead of `wss://`) | All messages (including code content and tokens) transmitted in plaintext | Always use `wss://` through the NAS reverse proxy with valid HTTPS certificate |
| Unencrypted NAS Docker network between relay and reverse proxy | Traffic between relay container and Nginx could be sniffed if compromised | Use Docker internal network (not host mode); containers on same Docker network are isolated from external access |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No connection status indicator | User does not know if messages are being delivered; sends duplicate messages | Show a clear connection state indicator (connected/connecting/disconnected) with last-known-good timestamp |
| Silent message loss | User thinks instruction was sent, waits forever for response that will never come | Show send confirmation (checkmark) only after server ACK; show "sending..." state while queued |
| No offline queue visibility | User sends 5 messages while disconnected, has no idea if they will be delivered | Show a "N messages queued" indicator when offline; let user see/cancel queued messages |
| Voice input button that does nothing on unsupported devices | User taps mic button, nothing happens or gets a cryptic error | Detect speech recognition availability at startup; hide or disable voice button with tooltip if unavailable; suggest using keyboard voice input |
| Reconnection without state recovery | After reconnect, chat history shows a gap; user does not know what they missed | On reconnect, request missed messages from relay server (requires server-side message buffer); show "syncing..." state |

## "Looks Done But Isn't" Checklist

- [ ] **WebSocket connection:** Often missing heartbeat timeout detection -- verify that connections are force-closed and reconnected when pong is not received within 8 seconds
- [ ] **Reconnection logic:** Often missing exponential backoff -- verify that reconnect delay increases with each attempt, not constant 1-second retry
- [ ] **Background/foreground transition:** Often missing lifecycle handling -- verify that connection is force-refreshed on `AppLifecycleState.resumed`, not just "check if open"
- [ ] **Nginx reverse proxy:** Often missing WebSocket upgrade headers AND timeout config -- verify with `wscat -c wss://5945.top/ws` from external network, then wait 90 seconds idle
- [ ] **Push notifications:** Often only tested on emulator with Google Play Services -- verify on the actual target Chinese phone with app killed
- [ ] **Voice input:** Often only tested with English locale -- verify with Chinese Mandarin input on the actual target device, both online and offline
- [ ] **Message delivery:** Often missing send queue -- verify by sending a message, immediately turning on airplane mode, turning it off, and checking if the message arrives at the desktop
- [ ] **Security:** Often missing token validation on relay server -- verify that connecting to `wss://5945.top/ws` without a valid token is rejected
- [ ] **Multiple connections:** Often pages create duplicate connections -- verify by checking server logs for concurrent connections after navigating through 3-4 pages in the app

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| No heartbeat / silent stall | MEDIUM | Add heartbeat to connection manager; add last-activity-timeout guard; requires modifying both client and server message handling |
| Nginx 60s timeout | LOW | Add timeout directives to Nginx/reverse proxy config; restart Nginx or redeploy proxy container |
| FCM on Chinese phones | HIGH | Rip out FCM; integrate manufacturer-specific push SDK or implement HTTP polling fallback; requires new Flutter plugin integration and server endpoint |
| No message queue | MEDIUM | Add client-side send queue to connection manager; add server-side message buffer to relay; add message ACK protocol; requires modifying both client and server |
| Multiple WebSocket instances | MEDIUM | Refactor to singleton connection manager; convert all pages from "create connection" to "subscribe to stream"; requires rewriting all pages that use WebSocket |
| No lifecycle handling | MEDIUM | Add WidgetsBindingObserver to connection manager; add force-reconnect on resume; requires modifying connection manager and testing all lifecycle transitions |
| Missing WSS headers in reverse proxy | LOW | Add WebSocket custom headers in DSM reverse proxy settings; no code changes needed |
| Speech recognition unavailable | LOW | Switch to IME-based voice input (no code needed) or integrate cloud speech API; depends on chosen approach |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Silent stall (no heartbeat) | Phase 1: Connection Manager | Kill WiFi during active chat, wait 20s, restore WiFi -- messages should resume within 30s |
| Nginx 60s timeout | Phase 1: Infrastructure Setup | `wscat -c wss://5945.top/ws`, wait 90s idle -- connection should remain alive |
| FCM on Chinese phones | Phase 2: Push Notifications | Kill app on target Chinese phone, trigger notification from desktop -- notification should arrive within 10s |
| SDK 35 background kill | Phase 1: Connection Manager | Send app to background for 30s, bring to foreground -- connection should auto-reconnect within 5s |
| No message queue | Phase 1: Connection Manager + Relay | Enable airplane mode, send 5 messages, disable airplane mode -- all 5 should arrive at desktop in order |
| Multiple WS instances | Phase 1: Architecture | Navigate through 3 pages, check server logs -- should show exactly 1 connection |
| Missing WSS headers | Phase 1: Infrastructure Setup | `wscat -c wss://5945.top/ws` from external network -- should connect successfully |
| Speech recognition | Phase 2: Voice Input | Test voice input button on actual Chinese phone with and without internet |

## Sources

- Flutter GitHub Issue #164368 -- Internet problem in background while using SDK 35: https://github.com/flutter/flutter/issues/164368
- Dev.to -- WebSockets Can Stall Without Disconnecting, And It Is Worse on Android: https://dev.to/jit_chakraborty_4222410eb/websockets-can-stall-without-disconnecting-and-its-worse-on-android-3n6e
- Juejin -- WebSocket long connection and reconnection mechanisms (Flutter practical): https://juejin.cn/post/7621739156106412067
- StackOverflow -- Can I keep a WebSocket connection in background/terminated state on Android: https://stackoverflow.com/questions/75195746/
- Ably -- Essential Guide to WebSocket Authentication: https://ably.com/blog/websocket-authentication
- WebSocket.org -- WebSocket Security: Auth, TLS, CSWSH and Rate Limiting: https://websocket.org/guides/security/
- Reddit r/fossdroid -- How do Android users in China receive push notifications without Play Services: https://www.reddit.com/r/fossdroid/comments/16ieaub/
- GitHub msgbyte/tailchat #74 -- About the ecological issue of Android push in China: https://github.com/msgbyte/tailchat/issues/74
- Juejin -- Android manufacturer push integration unified adaptation: https://juejin.cn/post/7476127574607888393
- Pushy -- Why do some Chinese devices fail to receive notifications in the background: https://support.pushy.me/hc/en-us/articles/360043864791
- Synology Knowledge Center -- DSM 7 Advanced Reverse Proxy configuration: https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/system_login_portal_advanced
- GitHub orobardet/dsm-reverse-proxy-websocket -- Synology DSM WebSocket config history: https://github.com/orobardet/dsm-reverse-proxy-websocket
- Reddit r/selfhosted -- How to increase the connection timeout of Nginx Proxy Manager: https://www.reddit.com/r/selfhosted/comments/15wukeq/
- Hacker News -- Tip for anyone using nginx to proxy websockets: https://news.ycombinator.com/item?id=5602046
- Ably -- Building Realtime Apps with Flutter and WebSockets: https://ably.com/topic/websockets-flutter
- Picovoice -- Offline Speech Recognition in Flutter: https://medium.com/picovoice/offline-speech-recognition-in-flutter-no-siri-no-google-and-no-its-not-speech-to-text-c960180e9239
- Pub.dev -- speech_to_text Flutter package: https://pub.dev/packages/speech_to_text
- OneUptime -- How to Implement Reconnection Logic for WebSockets: https://oneuptime.com/blog/post/2026-01-27-websocket-reconnection/view
- Socket.IO -- Delivery Guarantees documentation: https://socket.io/docs/v4/delivery-guarantees
- Ably -- WebSocket Reliability in Realtime Infrastructure: https://ably.com/topic/websocket-reliability-in-realtime-infrastructure

---
*Pitfalls research for: wzxClaw Android (Flutter + NAS WebSocket Relay)*
*Researched: 2026-04-09*
