# wzxClaw Android

Flutter mobile companion app for the [wzxClaw](https://github.com/wzx011011/wzClaw) AI coding IDE.

## Overview

Connects to a running wzxClaw desktop instance over a WebSocket tunnel (ngrok), giving you full chat access from your phone. Send messages, view streaming AI responses, and monitor tool execution — all from Android.

## Features

- **Real-time Chat** — send messages and see token-by-token streaming from the AI agent
- **WebSocket bridge** — connects to wzxClaw desktop via ngrok tunnel URL
- **Voice input** — long-press mic button for speech-to-text using system locale (Chinese devices get Chinese recognition)
- **Dark theme** — custom `AppColors` design system with a dark Midnight palette
- **Session management** — lists all conversations, resume or start new sessions
- **Tool execution cards** — inline display of FileRead, FileWrite, Bash, and other tool calls as they happen

## Screenshots

> Coming soon

## Requirements

- Android 6.0+ (API 23+)
- wzxClaw desktop running with the Mobile Bridge enabled (Settings → Mobile)
- ngrok tunnel URL from the desktop app

## Installation

Download the latest APK from [Releases](../../releases), install it on your device (enable "Install from unknown sources" if prompted).

### Build from source

```bash
# Prerequisites: Flutter 3.x stable, Java 17
flutter pub get
flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk
```

## Usage

1. Start wzxClaw on your desktop
2. In Settings → Mobile, enable the tunnel and copy the ngrok URL
3. Open wzxClaw Android, paste the URL on the connection screen
4. Tap **Connect** — the chat panel opens when the handshake succeeds

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3 (Dart) |
| State | Provider + StreamController.broadcast() |
| WebSocket | `web_socket_channel` |
| Voice | `speech_to_text` |
| Permissions | `permission_handler` |
| Design | Custom `AppColors` theme extension |

## Project structure

```
lib/
├── config/            # AppColors, constants
├── models/            # ChatMessage, SessionMeta, WsMessage, ConnectionState
├── services/          # WebSocketService, VoiceInputService, ConnectionManager
├── widgets/           # MicButton, ToolCallCard, StreamingText, …
└── screens/           # ConnectionScreen, ChatScreen, SessionListScreen
```

## License

Personal use. Not open-sourced.
