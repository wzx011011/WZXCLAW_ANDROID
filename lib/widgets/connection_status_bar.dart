import 'package:flutter/material.dart';

import '../models/connection_state.dart';

/// A thin status bar showing the current WebSocket connection state.
///
/// Displays a colored dot and Chinese label for each [WsConnectionState]:
/// - connected: green dot, "已连接"
/// - connecting: yellow dot, "连接中"
/// - reconnecting: yellow dot, "重连中"
/// - disconnected: red dot, "已断开"
class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({super.key, required this.state, this.desktopIdentity});

  final WsConnectionState state;
  final String? desktopIdentity;

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor(state);
    final bgColor = _backgroundColor(state);

    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: dotColor.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state == WsConnectionState.connected && desktopIdentity != null
                ? '已连接到 $desktopIdentity'
                : state.label,
            style: TextStyle(
              color: dotColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor(WsConnectionState state) {
    switch (state) {
      case WsConnectionState.connected:
        return Colors.green;
      case WsConnectionState.connecting:
      case WsConnectionState.reconnecting:
        return Colors.yellow;
      case WsConnectionState.disconnected:
        return Colors.red;
    }
  }

  Color _backgroundColor(WsConnectionState state) {
    switch (state) {
      case WsConnectionState.connected:
        return Colors.green.withOpacity(0.08);
      case WsConnectionState.connecting:
      case WsConnectionState.reconnecting:
        return Colors.yellow.withOpacity(0.08);
      case WsConnectionState.disconnected:
        return Colors.red.withOpacity(0.08);
    }
  }
}
