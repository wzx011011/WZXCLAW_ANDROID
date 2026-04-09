import 'package:flutter/material.dart';

import '../models/connection_state.dart';
import '../services/connection_manager.dart';
import '../services/project_store.dart';
import 'project_list_tile.dart';

/// Drawer widget containing the project list, empty state, disconnected
/// state, and a connection status footer.
///
/// Subscribes to [ProjectStore] and [ConnectionManager] streams to
/// reactively display the project list and connection status.
class ProjectDrawer extends StatefulWidget {
  const ProjectDrawer({super.key});

  @override
  State<ProjectDrawer> createState() => _ProjectDrawerState();
}

class _ProjectDrawerState extends State<ProjectDrawer> {
  List<Project> _projects = [];
  String? _currentProjectName;
  bool _isLoading = false;
  bool _hasFetchedOnce = false;

  @override
  void initState() {
    super.initState();
    // Auto-fetch on first open if list is empty
    if (ProjectStore.instance.projects.isEmpty && !_hasFetchedOnce) {
      _hasFetchedOnce = true;
      // Delay to allow drawer animation to start
      Future.microtask(() => ProjectStore.instance.fetchProjects());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A2E),
      width: 304,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildProjectList()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
            '项目',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<String?>(
            stream: ProjectStore.instance.currentProjectStream,
            initialData: ProjectStore.instance.currentProjectName,
            builder: (context, snapshot) {
              final name = snapshot.data;
              return Text(
                name != null && name.isNotEmpty
                    ? name
                    : '未选择项目',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    return StreamBuilder<WsConnectionState>(
      stream: ConnectionManager.instance.stateStream,
      initialData: ConnectionManager.instance.state,
      builder: (context, stateSnapshot) {
        final isDisconnected =
            stateSnapshot.data == WsConnectionState.disconnected;

        return StreamBuilder<List<Project>>(
          stream: ProjectStore.instance.projectsStream,
          initialData: ProjectStore.instance.projects,
          builder: (context, snapshot) {
            final projects = snapshot.data ?? [];

            // Disconnected state
            if (isDisconnected) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '未连接 -- 无法获取项目',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Empty state
            if (projects.isEmpty && !_isLoading) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '暂无项目',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '未能获取桌面端项目列表，请确认桌面端已连接',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Project list with pull-to-refresh
            return RefreshIndicator(
              color: const Color(0xFF6366F1),
              backgroundColor: const Color(0xFF16213E),
              onRefresh: () async {
                ProjectStore.instance.fetchProjects();
                // Wait briefly for the fetch to start, then let stream update UI
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: StreamBuilder<String?>(
                stream: ProjectStore.instance.currentProjectStream,
                initialData: ProjectStore.instance.currentProjectName,
                builder: (context, currentSnapshot) {
                  return ListView.builder(
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final isActive = project.name == currentSnapshot.data;
                      return ProjectListTile(
                        project: project,
                        isActive: isActive,
                        onTap: () {
                          ProjectStore.instance.switchProject(project.name);
                          Navigator.pop(context); // Close drawer per Pitfall 4
                        },
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
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
