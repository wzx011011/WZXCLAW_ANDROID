import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Shimmer "Thinking..." indicator shown while waiting for the first token.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with TickerProviderStateMixin {
  static const _phrases = ['Thinking...', 'Reasoning...', 'Analyzing...', 'Evaluating...'];

  late final AnimationController _shimmerController;
  late final AnimationController _dotController;
  late final AnimationController _fadeController;
  Timer? _phraseTimer;
  int _phraseIndex = 0;

  @override
  void initState() {
    super.initState();
    _phraseIndex = Random().nextInt(_phrases.length);

    // Shimmer sweep: 2s loop
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Dot pulse: 1.5s loop
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Phrase fade
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    // Rotate phrases every 3s
    _phraseTimer = Timer.periodic(const Duration(seconds: 3), (_) => _nextPhrase());
  }

  void _nextPhrase() {
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    _shimmerController.dispose();
    _dotController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 48, top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing dot
          AnimatedBuilder(
            animation: _dotController,
            builder: (_, __) => Opacity(
              opacity: 0.4 + _dotController.value * 0.6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Shimmer text
          FadeTransition(
            opacity: _fadeController,
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (_, __) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    final dx = _shimmerController.value * 3 - 1;
                    return LinearGradient(
                      begin: Alignment(dx - 0.3, 0),
                      end: Alignment(dx + 0.3, 0),
                      colors: const [
                        AppColors.textMuted,
                        AppColors.accent,
                        AppColors.textMuted,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    _phrases[_phraseIndex],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white, // masked by shader
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
