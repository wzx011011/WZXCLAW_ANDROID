import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../models/chat_message.dart';

/// A collapsible card that displays a tool call with input/output details.
/// Matches the desktop wzxClaw ToolCard component.
class ToolCard extends StatefulWidget {
  final ChatMessage message;

  const ToolCard({super.key, required this.message});

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard>
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
  void didUpdateWidget(ToolCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.toolStatus == ToolCallStatus.running) {
      if (!_spinController.isAnimating) _spinController.repeat();
    } else {
      _spinController.stop();
      // Auto-expand when error arrives
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
    final hasDetails =
        (msg.toolInput != null && msg.toolInput!.isNotEmpty) ||
            (msg.toolOutput != null && msg.toolOutput!.isNotEmpty);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Header (always visible) --
          InkWell(
            onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  _buildIcon(msg.toolName ?? ''),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.toolName ?? 'Tool',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (msg.toolInput != null &&
                            msg.toolInput!.isNotEmpty)
                          Text(
                            msg.toolInput!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if ((msg.toolName == 'Write' || msg.toolName == 'FileWrite' ||
                             msg.toolName == 'Edit' || msg.toolName == 'FileEdit') &&
                            msg.toolOutput != null && msg.toolOutput!.isNotEmpty)
                          Text(
                            msg.toolStatus == ToolCallStatus.done ? '✓ 文件已修改' : '修改中...',
                            style: TextStyle(
                              color: msg.toolStatus == ToolCallStatus.error
                                  ? AppColors.toolError
                                  : AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                  if (hasDetails) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // -- Expanded details --
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded && hasDetails
              ? Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 6),
                  if (msg.toolOutput != null && msg.toolOutput!.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text('Output',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 10)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: msg.toolOutput!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Icon(Icons.copy,
                              size: 14, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          msg.toolOutput!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
              : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(String toolName) {
    IconData icon;
    switch (toolName) {
      case 'Bash':
        icon = Icons.terminal;
        break;
      case 'Read':
      case 'file-read':
        icon = Icons.description_outlined;
        break;
      case 'Write':
      case 'file-write':
        icon = Icons.edit_note;
        break;
      case 'Edit':
      case 'file-edit':
        icon = Icons.compare_arrows;
        break;
      case 'Glob':
        icon = Icons.folder_open;
        break;
      case 'Grep':
        icon = Icons.search;
        break;
      case 'WebSearch':
      case 'web-search':
        icon = Icons.travel_explore;
        break;
      case 'WebFetch':
      case 'web-fetch':
        icon = Icons.cloud_download_outlined;
        break;
      case 'Agent':
      case 'agent-tool':
        icon = Icons.smart_toy_outlined;
        break;
      default:
        icon = Icons.build_outlined;
    }
    return Icon(icon, size: 16, color: AppColors.textSecondary);
  }

  Widget _buildStatusBadge(ToolCallStatus status) {
    Color color;
    String label;
    switch (status) {
      case ToolCallStatus.running:
        color = AppColors.toolRunning;
        label = 'Running';
        break;
      case ToolCallStatus.done:
        color = AppColors.toolCompleted;
        label = 'Done';
        break;
      case ToolCallStatus.error:
        color = AppColors.toolError;
        label = 'Error';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == ToolCallStatus.running)
            RotationTransition(
              turns: _spinController,
              child: Icon(Icons.sync, size: 10, color: color),
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
