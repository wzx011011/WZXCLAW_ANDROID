import 'package:flutter/material.dart';

/// Theme constants aligned with the wzxClaw desktop Midnight theme.
class AppColors {
  AppColors._();

  // -- Backgrounds --
  static const bgPrimary = Color(0xFF181818);
  static const bgSecondary = Color(0xFF1F1F1F);
  static const bgTertiary = Color(0xFF2B2B2B);
  static const bgElevated = Color(0xFF323232);
  static const bgInput = Color(0xFF141414);

  // -- Text --
  static const textPrimary = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFF808080);
  static const textMuted = Color(0xFF5A5A5A);

  // -- Accent --
  static const accent = Color(0xFF7C3AED);
  static const accentHover = Color(0xFF6D28D9);

  // -- Borders --
  static const border = Color(0xFF2E2E2E);

  // -- Semantic --
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);

  // -- Tool status --
  static const toolRunning = Color(0xFFDCB67A);
  static const toolCompleted = Color(0xFF89D185);
  static const toolError = Color(0xFFF48771);

  // -- User/Assistant bubble --
  static const userBubble = accent;
  static const assistantBubble = bgTertiary;
}
