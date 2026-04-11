import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/chat_store.dart';

/// A bar that appears when the desktop agent asks the user a question
/// via the AskUserQuestion tool.
///
/// - Single-select: tapping an option immediately sends the response.
/// - Multi-select: toggle options with checkboxes, then press Submit.
/// - "Other" option: opens a text field for free-form input.
class AskUserBar extends StatefulWidget {
  final AskUserQuestion question;
  const AskUserBar({super.key, required this.question});

  @override
  State<AskUserBar> createState() => _AskUserBarState();
}

class _AskUserBarState extends State<AskUserBar> {
  final Set<String> _selected = {};
  bool _showOther = false;
  final _otherController = TextEditingController();

  static const _accentColor = Color(0xFF6366F1); // indigo-500
  static const _accentLight = Color(0xFF818CF8); // indigo-400

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _submitSelection() {
    ChatStore.instance.respondToAskUser(
      widget.question.questionId,
      _selected.toList(),
    );
  }

  void _submitOther() {
    final text = _otherController.text.trim();
    if (text.isEmpty) return;
    ChatStore.instance.respondToAskUser(
      widget.question.questionId,
      [],
      customText: text,
    );
  }

  void _onSingleSelect(String label) {
    ChatStore.instance.respondToAskUser(
      widget.question.questionId,
      [label],
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final hasOptions = q.options.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border.all(color: _accentColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.help_outline, size: 16, color: _accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Question',
                  style: const TextStyle(
                    color: _accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (q.multiSelect)
                const Text(
                  'Select multiple',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Question text
          Text(
            q.question,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          // Options
          if (hasOptions) ...[
            const SizedBox(height: 10),
            ...q.options.map((opt) {
              final label = opt['label'] ?? '';
              final description = opt['description'] ?? '';
              final isSelected = _selected.contains(label);

              if (q.multiSelect) {
                return _buildMultiSelectOption(
                    label, description, isSelected);
              } else {
                return _buildSingleSelectOption(label, description);
              }
            }),
          ],
          // "Other" toggle
          const SizedBox(height: 8),
          if (!_showOther)
            GestureDetector(
              onTap: () => setState(() => _showOther = true),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    const Text(
                      'Other...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // "Other" text field
          if (_showOther) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otherController,
                    autofocus: true,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Type your answer...',
                      hintStyle:
                          const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _submitOther(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _submitOther,
                  icon: const Icon(Icons.send, color: _accentColor, size: 20),
                  tooltip: 'Submit',
                ),
                IconButton(
                  onPressed: () => setState(() => _showOther = false),
                  icon: const Icon(Icons.close,
                      color: AppColors.textMuted, size: 20),
                  tooltip: 'Cancel',
                ),
              ],
            ),
          ],
          // Multi-select submit button
          if (q.multiSelect && _selected.isNotEmpty && !_showOther) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitSelection,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _accentColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Submit (${_selected.length})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleSelectOption(String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => _onSingleSelect(label),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _accentLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectOption(
      String label, String description, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selected.remove(label);
            } else {
              _selected.add(label);
            }
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? _accentColor.withOpacity(0.15)
                : AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? _accentColor : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: isSelected ? _accentColor : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? _accentLight
                            : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
