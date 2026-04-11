import 'package:flutter/material.dart';

import '../models/connection_state.dart';
import '../models/session_meta.dart';
import '../services/chat_store.dart';
import '../services/connection_manager.dart';
import '../services/session_sync_service.dart';
import 'session_list_tile.dart';

/// Drawer widget displaying the current desktop workspace and its sessions.
///
/// Subscribes to [SessionSyncService] for workspace info and session list,
/// and [ConnectionManager] for connection status.
class ProjectDrawer extends StatelessWidget {
  const ProjectDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A2E),
      width: 304,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildWorkspaceSection(),
                const Divider(color: Colors.white12, height: 1),
                _buildFileBrowseEntry(context),
                const Divider(color: Colors.white12, height: 1),
                _buildSessionSection(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<WorkspaceInfo?>(
      stream: SessionSyncService.instance.workspaceInfoStream,
      initialData: SessionSyncService.instance.workspaceInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Container(
          height: 120,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF16213E),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFF6366F1),
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '工作区',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                info?.workspaceName ?? '未连接',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkspaceSection() {
    return StreamBuilder<WsConnectionState>(
      stream: ConnectionManager.instance.stateStream,
      initialData: ConnectionManager.instance.state,
      builder: (context, stateSnapshot) {
        final isDisconnected =
            stateSnapshot.data == WsConnectionState.disconnected;

        if (isDisconnected) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '未连接 -- 无法获取工作区',
              style: TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          );
        }

        return StreamBuilder<WorkspaceInfo?>(
          stream: SessionSyncService.instance.workspaceInfoStream,
          initialData: SessionSyncService.instance.workspaceInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;

            if (info == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '等待桌面端推送工作区信息...',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListTile(
              leading: const Icon(Icons.folder_open,
                  color: Color(0xFF6366F1), size: 20,),
              title: Text(
                info.workspaceName,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                info.workspacePath,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              trailing: Text(
                '${info.sessionCount} 会话',
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFileBrowseEntry(BuildContext context) {
    return ListTile(
      leading:
          const Icon(Icons.folder_open, color: Colors.white54, size: 20),
      title: const Text('浏览文件',
          style: TextStyle(color: Colors.white70, fontSize: 14),),
      dense: true,
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/files');
      },
    );
  }

  Widget _buildSessionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.history, size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              const Text(
                '会话',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // New session button
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () async {
                    final result = await SessionSyncService.instance.createSession();
                    if (result != null) {
                      final sessionId = result['id'] as String?;
                      if (sessionId != null) {
                        ChatStore.instance.switchToSession(sessionId);
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.add, size: 16, color: Colors.white38),
                  ),
                ),
              ),
              // Refresh button
              StreamBuilder<bool>(
                stream: SessionSyncService.instance.loadingStream,
                initialData: SessionSyncService.instance.isLoading,
                builder: (context, snapshot) {
                  final isLoading = snapshot.data ?? false;
                  return GestureDetector(
                    onTap: isLoading
                        ? null
                        : () => SessionSyncService.instance.fetchSessions(),
                    child: isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white38,
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            size: 16,
                            color: Colors.white38,
                          ),
                  );
                },
              ),
            ],
          ),
        ),
        // Session list
        StreamBuilder<List<SessionMeta>>(
          stream: SessionSyncService.instance.sessionsStream,
          initialData: SessionSyncService.instance.sessions,
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? [];

            if (sessions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  '暂无会话记录',
                  style: TextStyle(color: Colors.white24, fontSize: 13),
                ),
              );
            }

            return StreamBuilder<String?>(
              stream: SessionSyncService.instance.activeSessionStream,
              initialData: SessionSyncService.instance.activeSessionId,
              builder: (context, activeSnapshot) {
                final activeId = activeSnapshot.data;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sessions.map((session) {
                    final isActive = session.id == activeId;
                    return SessionListTile(
                      session: session,
                      isActive: isActive,
                      onTap: () => _onSessionTap(context, session),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _onSessionTap(BuildContext context, SessionMeta session) async {
    SessionSyncService.instance.setActiveSession(session.id);

    // Load messages from desktop (or cache)
    try {
      final result =
          await SessionSyncService.instance.loadSessionMessages(session.id);
      final messages = result['messages'] as List<dynamic>? ?? [];
      ChatStore.instance.switchToSession(session.id);
      if (messages.isNotEmpty) {
        ChatStore.instance.loadFetchedMessages(messages.cast());
      }
    } catch (_) {
      // Fallback: just switch to whatever is cached
      ChatStore.instance.switchToSession(session.id);
    }

    if (context.mounted) Navigator.pop(context);
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white12, width: 0.5),
        ),
      ),
      child: StreamBuilder<WsConnectionState>(
        stream: ConnectionManager.instance.stateStream,
        initialData: ConnectionManager.instance.state,
        builder: (context, snapshot) {
          final state = snapshot.data ?? WsConnectionState.disconnected;
          final dotColor = _statusColor(state);
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.label,
                style: TextStyle(
                  color: dotColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(WsConnectionState state) {
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
}
