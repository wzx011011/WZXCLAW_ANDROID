import 'package:flutter/material.dart';

import '../models/project.dart';

/// A single project row widget for the project drawer list.
///
/// Displays a status dot (green = running, grey = idle), the project name,
/// and a check icon if this is the currently active project.
class ProjectListTile extends StatelessWidget {
  const ProjectListTile({
    super.key,
    required this.project,
    required this.isActive,
    required this.onTap,
  });

  final Project project;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: const Color(0xFF6366F1).withOpacity(0.12),
      highlightColor: const Color(0xFF6366F1).withOpacity(0.12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: isActive ? const Color(0xFF6366F1).withOpacity(0.12) : null,
        child: Row(
          children: [
            // Status dot: 8px circle
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: project.isRunning ? Colors.green : Colors.white38,
              ),
            ),
            const SizedBox(width: 12), // Legacy exception: 12px gap per UI-SPEC
            // Project name
            Expanded(
              child: Text(
                project.name,
                style: TextStyle(
                  fontSize: 15,
                  color: isActive ? Colors.white : Colors.white70,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Check icon for active project
            if (isActive)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF6366F1),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
