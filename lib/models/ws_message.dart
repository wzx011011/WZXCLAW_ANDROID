import 'dart:convert';

/// WebSocket message model matching the wzxClaw desktop protocol.
///
/// All messages exchanged between the mobile client and the desktop IDE
/// follow this JSON structure: `{ "event": "...", "data": ... }`.
class WsMessage {
  /// Event name (e.g., "command:send", "stream:text_delta").
  final String event;

  /// Payload -- can be a string, map, list, or null.
  final dynamic data;

  WsMessage({required this.event, this.data});

  /// Parse from JSON received over the wire.
  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      event: json['event'] as String? ?? '',
      data: json['data'],
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'event': event,
      if (data != null) 'data': data,
    };
  }

  /// Serialize to JSON string for sending over WebSocket.
  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() => 'WsMessage(event: $event, data: $data)';
}

/// Event name constants matching the wzxClaw desktop WebSocket protocol.
class WsEvents {
  WsEvents._();

  // -- Outgoing (client -> server) --
  /// Send a user command to the desktop IDE.
  static const String commandSend = 'command:send';

  /// Request the desktop IDE to stop the current AI generation.
  static const String commandStop = 'command:stop';

  /// Application-level ping (not WebSocket protocol-level).
  static const String ping = 'ping';

  /// Application-level pong (not WebSocket protocol-level).
  static const String pong = 'pong';

  // -- Incoming (server -> client) --
  /// Connection confirmed by the desktop IDE.
  static const String connected = 'connected';

  /// User message echoed back from the desktop.
  static const String messageUser = 'message:user';

  /// Full assistant message from the desktop.
  static const String messageAssistant = 'message:assistant';

  /// Incremental text chunk during streaming.
  static const String streamTextDelta = 'stream:text_delta';

  /// Tool use started during AI generation.
  static const String streamToolUseStart = 'stream:tool_use_start';

  /// Generation complete.
  static const String streamDone = 'stream:done';

  /// Error during streaming.
  static const String streamError = 'stream:error';

  /// Full session history sync (array of {role, content}).
  static const String sessionMessages = 'session:messages';
}
