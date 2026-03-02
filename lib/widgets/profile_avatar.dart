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
    final fallbackChar = fallbackText?.isNotEmpty == true ? fallbackText![0] : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: borderWidth > 0 && borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: hasImage
            ? (imageUrl!.startsWith('assets/')
                  ? Image.asset(
                      imageUrl!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      errorBuilder: (_, _, _) => _buildFallback(fallbackChar),
                    ))
            : _buildFallback(fallbackChar),
      ),
    );
  }

  Widget _buildFallback(String fallbackChar) {
    return Center(
      child: Text(
        fallbackChar,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
