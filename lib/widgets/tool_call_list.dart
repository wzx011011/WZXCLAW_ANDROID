import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../models/chat_message.dart';

/// Groups consecutive tool call messages into a compact list with a left
/// vertical connecting line, matching the Claude Code Agent UI style.
class ToolCallGroup extends StatelessWidget {
  final List<ChatMessage> tools;

  const ToolCallGroup({super.key, required this.tools});

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left vertical line
            Container(
              width: 2,
              margin: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 10),
            // Tool entries
            Expanded(
              child: Column(
                children: tools
                    .map((tool) => _ToolCallEntry(message: tool))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single compact tool call row.
class _ToolCallEntry extends StatefulWidget {
  final ChatMessage message;

  const _ToolCallEntry({required this.message});

  @override
  State<_ToolCallEntry> createState() => _ToolCallEntryState();
}

class _ToolCallEntryState extends State<_ToolCallEntry>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.message.toolStatus == ToolCallStatus.running) {
      _spinController.repeat();
    }
    // Auto-expand on error
    if (widget.message.toolStatus == ToolCallStatus.error) {
      _expanded = true;
    }
  }

  @override
  void didUpdateWidget(_ToolCallEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.toolStatus == ToolCallStatus.running) {
      if (!_spinController.isAnimating) _spinController.repeat();
    } else {
      _spinController.stop();
      if (widget.message.toolStatus == ToolCallStatus.error && !_expanded) {
        setState(() => _expanded = true);
      }
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final status = msg.toolStatus ?? ToolCallStatus.running;
    final toolName = msg.toolName ?? 'Tool';
    final hasOutput = msg.toolOutput != null && msg.toolOutput!.isNotEmpty;

    return Column(
      children: [
        // Main row
        InkWell(
          onTap: hasOutput ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            child: Row(
              children: [
                // Tool icon
                _buildIcon(toolName),
                const SizedBox(width: 8),
                // Action verb + input badge
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        _actionVerb(toolName, status),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (msg.toolInput != null && msg.toolInput!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: _buildInputBadge(toolName, msg.toolInput!),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Status icon
                _buildStatusIcon(status),
              ],
            ),
          ),
        ),
        // Expandable output
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _expanded && hasOutput
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(left: 28, right: 4, bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: SingleChildScrollView(
                            child: Text(
                              msg.toolOutput!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg.toolOutput!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Icon(Icons.copy,
                            size: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildIcon(String toolName) {
    IconData icon;
    switch (toolName) {
      case 'Bash':
        icon = Icons.terminal;
      case 'Read':
      case 'file-read':
        icon = Icons.description;
      case 'Write':
      case 'file-write':
        icon = Icons.edit_note;
      case 'Edit':
      case 'file-edit':
        icon = Icons.edit_note;
      case 'Glob':
        icon = Icons.folder_open;
      case 'Grep':
        icon = Icons.search;
      case 'WebSearch':
      case 'web-search':
        icon = Icons.travel_explore;
      case 'WebFetch':
      case 'web-fetch':
        icon = Icons.cloud_download_outlined;
      case 'Agent':
      case 'agent-tool':
        icon = Icons.smart_toy;
      default:
        icon = Icons.build_outlined;
    }
    return Icon(icon, size: 14, color: AppColors.textMuted);
  }

  String _actionVerb(String toolName, ToolCallStatus status) {
    final done = status != ToolCallStatus.running;
    switch (toolName) {
      case 'Bash':
        return done ? 'Ran' : 'Running';
      case 'Read':
      case 'file-read':
        return done ? 'Read' : 'Reading';
      case 'Write':
      case 'file-write':
        return done ? 'Wrote' : 'Writing';
      case 'Edit':
      case 'file-edit':
        return done ? 'Edited' : 'Editing';
      case 'Glob':
        return done ? 'Found' : 'Finding';
      case 'Grep':
        return done ? 'Searched' : 'Searching';
      case 'WebSearch':
      case 'web-search':
        return done ? 'Searched' : 'Searching';
      case 'WebFetch':
      case 'web-fetch':
        return done ? 'Fetched' : 'Fetching';
      case 'Agent':
      case 'agent-tool':
        return done ? 'Ran agent' : 'Running agent';
      default:
        return done ? 'Used $toolName' : 'Using $toolName';
    }
  }

  Widget _buildInputBadge(String toolName, String input) {
    // Extract filename from path
    String display = input;
    if (input.contains('/') || input.contains('\\')) {
      display = input.split(RegExp(r'[/\\]')).last;
    }
    if (display.length > 40) {
      display = '${display.substring(0, 37)}...';
    }

    final badgeColor = _badgeColor(toolName, display);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        display,
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontFamily: toolName == 'Bash' ? 'monospace' : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _badgeColor(String toolName, String display) {
    if (toolName == 'Bash') return const Color(0xFF9E9E9E);
    // Color by file extension
    if (display.endsWith('.dart')) return const Color(0xFF64B5F6);
    if (display.endsWith('.tsx') || display.endsWith('.ts')) {
      return const Color(0xFF4DD0E1);
    }
    if (display.endsWith('.css') || display.endsWith('.scss')) {
      return const Color(0xFFCE93D8);
    }
    if (display.endsWith('.js') || display.endsWith('.jsx')) {
      return const Color(0xFFFFD54F);
    }
    if (display.endsWith('.json')) return const Color(0xFFA5D6A7);
    if (display.endsWith('.md')) return const Color(0xFF90CAF9);
    if (display.endsWith('.py')) return const Color(0xFF81C784);
    return AppColors.textSecondary;
  }

  Widget _buildStatusIcon(ToolCallStatus status) {
    switch (status) {
      case ToolCallStatus.running:
        return RotationTransition(
          turns: _spinController,
          child: const Icon(Icons.sync, size: 14, color: AppColors.toolRunning),
        );
      case ToolCallStatus.done:
        return const Icon(Icons.check, size: 14, color: AppColors.toolCompleted);
      case ToolCallStatus.error:
        return const Icon(Icons.close, size: 14, color: AppColors.toolError);
    }
  }
}
