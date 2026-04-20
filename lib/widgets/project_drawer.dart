import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/connection_state.dart';
import '../models/session_meta.dart';
import '../services/chat_store.dart';
import '../services/connection_manager.dart';
import '../services/session_sync_service.dart';
import '../services/task_service.dart';
import 'session_list_tile.dart';
import 'task_drawer.dart';

/// Drawer widget displaying the current desktop workspace and its sessions.
class ProjectDrawer extends StatelessWidget {
  const ProjectDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Drawer(
      backgroundColor: colors.bgPrimary,
      width: 304,
      child: Column(
        children: [
          _buildHeader(colors),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildWorkspaceSection(colors),
                Divider(color: colors.border, height: 1),
                _buildFileBrowseEntry(context, colors),
                _buildTaskEntry(context, colors),
                Divider(color: colors.border, height: 1),
                _buildSessionSection(context, colors),
              ],
            ),
          ),
          _buildFooter(colors),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return StreamBuilder<bool>(
      stream: ConnectionManager.instance.desktopOnlineStream,
      initialData: ConnectionManager.instance.desktopOnline,
      builder: (context, desktopSnap) {
        final desktopOnline = desktopSnap.data ?? false;
        return StreamBuilder<WorkspaceInfo?>(
          stream: SessionSyncService.instance.workspaceInfoStream,
          initialData: SessionSyncService.instance.workspaceInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;
            String subtitle;
            if (desktopOnline && info != null) {
              subtitle = info.workspaceName;
            } else if (desktopOnline) {
              subtitle = '加载中...';
            } else {
              subtitle = '未连接';
            }
            return Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: colors.bgSecondary,
                border: Border(
                  bottom: BorderSide(color: colors.accent, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '工作区',
                    style: TextStyle(
                      fontSize: 20,
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWorkspaceSection(AppColors colors) {
    return StreamBuilder<WsConnectionState>(
      stream: ConnectionManager.instance.stateStream,
      initialData: ConnectionManager.instance.state,
      builder: (context, stateSnapshot) {
        final isDisconnected =
            stateSnapshot.data == WsConnectionState.disconnected;

        if (isDisconnected) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '未连接 -- 无法获取工作区',
              style: TextStyle(color: colors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          );
        }

        return StreamBuilder<bool>(
          stream: ConnectionManager.instance.desktopOnlineStream,
          initialData: ConnectionManager.instance.desktopOnline,
          builder: (context, desktopSnap) {
            final desktopOnline = desktopSnap.data ?? false;

            if (!desktopOnline) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '已连接中继，等待桌面端上线...',
                  style: TextStyle(color: colors.textMuted, fontSize: 14),
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
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '等待桌面端推送工作区信息...',
                      style: TextStyle(color: colors.textMuted, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListTile(
                  leading: Icon(Icons.folder_open, color: colors.accent, size: 20),
                  title: Text(
                    info.workspaceName,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    info.workspacePath,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  trailing: Text(
                    '${info.sessionCount} 会话',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFileBrowseEntry(BuildContext context, AppColors colors) {
    return ListTile(
      leading: Icon(Icons.folder_open, color: colors.textSecondary, size: 20),
      title: Text(
        '浏览文件',
        style: TextStyle(color: colors.textSecondary, fontSize: 14),
      ),
      dense: true,
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/files');
      },
    );
  }

  Widget _buildTaskEntry(BuildContext context, AppColors colors) {
    return StreamBuilder<String?>(
      stream: TaskService.instance.activeTaskIdStream,
      initialData: TaskService.instance.activeTaskId,
      builder: (context, snapshot) {
        final hasActive = snapshot.data != null;
        return ListTile(
          leading: Icon(
            Icons.task_alt,
            color: hasActive ? colors.accent : colors.textSecondary,
            size: 20,
          ),
          title: Text(
            '任务',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          trailing: hasActive
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '已选',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
          dense: true,
          onTap: () {
            // Capture the Navigator widget's context (above the route) so it
            // remains valid after pop removes this widget from the tree.
            final navigator = Navigator.of(context);
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showTaskDrawer(navigator.context);
            });
          },
        );
      },
    );
  }

  Widget _buildSessionSection(BuildContext context, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.history, size: 16, color: colors.textSecondary),
              const SizedBox(width: 8),
              Text(
                '会话',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () async {
                    final result =
                        await SessionSyncService.instance.createSession();
                    if (result != null) {
                      final sessionId = result['id'] as String?;
                      if (sessionId != null) {
                        ChatStore.instance.switchToSession(sessionId);
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child:
                        Icon(Icons.add, size: 16, color: colors.textMuted),
                  ),
                ),
              ),
              StreamBuilder<bool>(
                stream: SessionSyncService.instance.loadingStream,
                initialData: SessionSyncService.instance.isLoading,
                builder: (context, snapshot) {
                  final isLoading = snapshot.data ?? false;
                  return GestureDetector(
                    onTap: isLoading
                        ? null
                        : () =>
                            SessionSyncService.instance.fetchSessions(),
                    child: isLoading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: colors.textMuted,
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 16,
                            color: colors.textMuted,
                          ),
                  );
                },
              ),
            ],
          ),
        ),
        StreamBuilder<List<SessionMeta>>(
          stream: SessionSyncService.instance.sessionsStream,
          initialData: SessionSyncService.instance.sessions,
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? [];

            if (sessions.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  '暂无会话记录',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
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

    try {
      final result =
          await SessionSyncService.instance.loadSessionMessages(session.id);
      final messages = result['messages'] as List<dynamic>? ?? [];
      ChatStore.instance.switchToSession(session.id);
      if (messages.isNotEmpty) {
        ChatStore.instance.loadFetchedMessages(messages.cast());
      }
    } catch (_) {
      ChatStore.instance.switchToSession(session.id);
    }

    if (context.mounted) Navigator.pop(context);
  }

  Widget _buildFooter(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.border, width: 0.5),
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
        return Colors.orange;
      case WsConnectionState.disconnected:
        return Colors.red;
    }
  }
}
