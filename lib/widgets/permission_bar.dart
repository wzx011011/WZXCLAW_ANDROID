import 'dart:convert';

import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/chat_store.dart';

/// A bar that appears when the desktop agent requests permission for a tool.
class PermissionBar extends StatelessWidget {
  final PermissionRequest request;

  const PermissionBar({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    // Build a short summary of the input
    String inputSummary = '';
    if (request.input.isNotEmpty) {
      final encoded = const JsonEncoder.withIndent('  ').convert(request.input);
      inputSummary =
          encoded.length > 300 ? '${encoded.substring(0, 300)}…' : encoded;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border.all(color: AppColors.toolRunning),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.security, size: 16, color: AppColors.toolRunning),
              const SizedBox(width: 6),
              Text(
                'Permission Request',
                style: TextStyle(
                  color: AppColors.toolRunning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${request.toolName} wants to execute:',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (inputSummary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  inputSummary,
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ChatStore.instance
                      .respondToPermission(request.toolCallId, false);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
                child: const Text('Deny', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  ChatStore.instance
                      .respondToPermission(request.toolCallId, true);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.success,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.success),
                  ),
                ),
                child: const Text('Approve', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
