import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/chat_store.dart';

/// A bar that appears when the desktop agent enters plan mode.
/// Shows the proposed plan and lets the user approve or reject execution.
class PlanModeBar extends StatelessWidget {
  final Map<String, dynamic> planData;

  const PlanModeBar({super.key, required this.planData});

  @override
  Widget build(BuildContext context) {
    final planContent = planData['plan'] as String? ??
        planData['planContent'] as String? ??
        planData['summary'] as String? ??
        '';

    final displayContent = planContent.isNotEmpty
        ? (planContent.length > 400
            ? '${planContent.substring(0, 400)}…'
            : planContent)
        : 'Agent has entered plan mode and is ready to execute.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                'Plan Mode',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Review the plan before execution',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 160),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              child: Text(
                displayContent,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ChatStore.instance.respondToPlan(false);
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
                child: const Text('Reject', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  ChatStore.instance.respondToPlan(true);
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
                child: const Text('Approve & Execute',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
