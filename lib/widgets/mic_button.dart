import 'package:flutter/material.dart';

import '../services/voice_input_service.dart';

/// Callback type for when voice recognition produces a final result.
typedef VoiceResultCallback = void Function(String text);

/// Mic button widget for voice input.
///
/// Long-press to start recording, release to stop.
/// Recognized text is sent to parent via [onResult] callback.
///
/// Visual states:
/// - Idle + connected: Icons.mic, Colors.white38
/// - Recording (pressed): Icons.mic with pulsing opacity 0.5-1.0 (800ms), Colors.redAccent
/// - Disconnected: Icons.mic, Colors.white24, non-interactive
class MicButton extends StatefulWidget {
  /// Called with recognized text when a final result is available.
  final VoiceResultCallback onResult;

  /// Whether the WebSocket is connected (enables/disables the button).
  final bool isConnected;

  /// Whether AI is currently streaming (de-emphasizes the button).
  final bool isStreaming;

  const MicButton({
    super.key,
    required this.onResult,
    required this.isConnected,
    this.isStreaming = false,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onLongPressStart(LongPressStartDetails details) async {
    if (!widget.isConnected || widget.isStreaming) return;

    setState(() => _isRecording = true);
    _pulseController.repeat(reverse: true);
    HapticFeedback.mediumImpact();

    VoiceInputService.instance.startListening(
      onResult: (text) {
        widget.onResult(text);
      },
    );
  }

  Future<void> _onLongPressEnd(LongPressEndDetails details) async {
    if (!_isRecording) return;

    _pulseController.stop();
    _pulseController.value = 0;
    setState(() => _isRecording = false);

    await VoiceInputService.instance.stopListening();
  }

  Color get _iconColor {
    if (!widget.isConnected) return Colors.white24;
    if (_isRecording) return Colors.redAccent;
    if (widget.isStreaming) return Colors.white24;
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: widget.isConnected && !widget.isStreaming
          ? _onLongPressStart
          : null,
      onLongPressEnd: _onLongPressEnd,
      child: Semantics(
        label: '语音输入',
        button: true,
        child: IconButton(
          onPressed: null, // Disable default tap -- we use long-press only
          icon: _isRecording
              ? FadeTransition(
                  opacity: Tween<double>(begin: 0.5, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Icon(Icons.mic, color: _iconColor),
                )
              : Icon(Icons.mic, color: _iconColor),
          tooltip: '语音输入',
        ),
      ),
    );
  }
}
