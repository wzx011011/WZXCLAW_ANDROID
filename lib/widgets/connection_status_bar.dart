import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/connection_state.dart';

/// A thin status bar showing the current WebSocket connection state.
class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({
    super.key,
    required this.state,
    this.desktopIdentity,
    this.errorMessage,
  });

  final WsConnectionState state;
  final String? desktopIdentity;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dotColor = _dotColor(state);
    final hasError = errorMessage != null &&
        errorMessage!.isNotEmpty &&
        state != WsConnectionState.connected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: dotColor.withValues(alpha: 0.3),
            width: 1,
          ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state == WsConnectionState.connected &&
                          desktopIdentity != null
                      ? '已连接到 $desktopIdentity'
                      : state.label,
                  style: TextStyle(
                    color: dotColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasError)
                  Text(
                    errorMessage!,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
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
        return Colors.orange;
      case WsConnectionState.disconnected:
        return Colors.red;
    }
  }
}
