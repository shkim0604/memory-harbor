import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 프로필 아바타 위젯
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackText;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.fallbackText,
    this.size = 48,
    this.borderColor,
    this.borderWidth = 0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final bgColor = backgroundColor ?? AppColors.accentLight;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasImage ? null : bgColor,
        border: borderWidth > 0 && borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
        image: hasImage
            ? DecorationImage(
                image: imageUrl!.startsWith('assets/')
                    ? AssetImage(imageUrl!) as ImageProvider
                    : NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasImage
          ? null
          : Center(
              child: Text(
                fallbackText?.isNotEmpty == true ? fallbackText![0] : '?',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentDark,
                ),
              ),
            ),
    );
  }
}
