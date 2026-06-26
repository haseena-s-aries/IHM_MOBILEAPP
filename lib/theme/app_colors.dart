import 'package:flutter/material.dart';

class AppColors {
  final Color bgDark;
  final Color bgCard;
  final Color bgCardAlt;
  final Color textPrimary;
  final Color textSecond;
  final Color divider;

  const AppColors({
    required this.bgDark,
    required this.bgCard,
    required this.bgCardAlt,
    required this.textPrimary,
    required this.textSecond,
    required this.divider,
  });

  static const dark = AppColors(
    bgDark: Color(0xFF0D1B2A),
    bgCard: Color(0xFF152235),
    bgCardAlt: Color(0xFF1A2C42),
    textPrimary: Color(0xFFE8F0FE),
    textSecond: Color(0xFF8FA8C4),
    divider: Color(0xFF1E3A55),
  );

  static const light = AppColors(
    bgDark: Color(0xFFF0F4FA),
    bgCard: Color(0xFFFFFFFF),
    bgCardAlt: Color(0xFFEAF0F9),
    textPrimary: Color(0xFF0D1B2A),
    textSecond: Color(0xFF4A6580),
    divider: Color(0xFFCDD9E8),
  );
}
