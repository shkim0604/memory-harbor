import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 분위기 태그 색상 매핑
class MoodColors {
  MoodColors._();

  static const Map<String, Color> colors = {
    '즐거움': AppColors.success,
    '그리움': AppColors.secondary,
    '따뜻함': AppColors.accent,
    '행복': AppColors.primary,
    '평온': AppColors.primaryLight,
  };

  static Color getColor(String? mood) {
    return colors[mood] ?? AppColors.textSecondary;
  }
}

/// 분위기 태그 위젯
class MoodTag extends StatelessWidget {
  final String mood;
  final double fontSize;

  const MoodTag({super.key, required this.mood, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final color = MoodColors.getColor(mood);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mood,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
