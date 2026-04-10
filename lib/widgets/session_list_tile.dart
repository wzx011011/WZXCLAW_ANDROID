import 'package:flutter/material.dart';

import '../models/session_meta.dart';

/// A single session row widget for the session list in the drawer.
///
/// Displays the session title, relative timestamp, message count,
/// and a highlight if this is the currently active session.
class SessionListTile extends StatelessWidget {
  const SessionListTile({
    super.key,
    required this.session,
    required this.isActive,
    required this.onTap,
  });

  final SessionMeta session;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: const Color(0xFF6366F1).withOpacity(0.12),
      highlightColor: const Color(0xFF6366F1).withOpacity(0.12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isActive ? const Color(0xFF6366F1).withOpacity(0.12) : null,
        child: Row(
          children: [
            // Chat bubble icon
            Icon(
              Icons.chat_bubble_outline,
              size: 16,
              color: isActive
                  ? const Color(0xFF6366F1)
                  : Colors.white38,
            ),
            const SizedBox(width: 12),
            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: TextStyle(
                      fontSize: 14,
                      color: isActive ? Colors.white : Colors.white70,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatTime(session.updatedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${session.messageCount} msgs',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                      if (!session.isSynced) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            '缓存',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Active indicator
            if (isActive)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF6366F1),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int epochMs) {
    if (epochMs == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}
