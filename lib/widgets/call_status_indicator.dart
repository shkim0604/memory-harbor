import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum CallStatus { connecting, onCall, ended }

/// 통화 상태 인디케이터
class CallStatusIndicator extends StatelessWidget {
  final CallStatus status;
  final String? duration;
  final bool showDuration;

  const CallStatusIndicator({
    super.key,
    required this.status,
    this.duration,
    this.showDuration = true,
  });

  Color get statusColor {
    switch (status) {
      case CallStatus.connecting:
        return AppColors.connecting;
      case CallStatus.onCall:
        return AppColors.onCall;
      case CallStatus.ended:
        return AppColors.ended;
    }
  }

  String get statusText {
    switch (status) {
      case CallStatus.connecting:
        return '연결 중';
      case CallStatus.onCall:
        return '통화 중';
      case CallStatus.ended:
        return '통화 종료';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          statusText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (showDuration &&
            status == CallStatus.onCall &&
            duration != null) ...[
          const SizedBox(width: 16),
          Text(
            duration!,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: Colors.white70,
              letterSpacing: 2,
            ),
          ),
        ],
      ],
    );
  }
}
