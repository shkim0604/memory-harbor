import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum CallSessionState { connecting, onCall, ended }

/// 통화 상태 인디케이터
class CallSessionStateIndicator extends StatelessWidget {
  final CallSessionState status;
  final String? duration;
  final bool showDuration;

  const CallSessionStateIndicator({
    super.key,
    required this.status,
    this.duration,
    this.showDuration = true,
  });

  Color get statusColor {
    switch (status) {
      case CallSessionState.connecting:
        return AppColors.connecting;
      case CallSessionState.onCall:
        return AppColors.onCall;
      case CallSessionState.ended:
        return AppColors.ended;
    }
  }

  String get statusText {
    switch (status) {
      case CallSessionState.connecting:
        return '연결 중';
      case CallSessionState.onCall:
        return '통화 중';
      case CallSessionState.ended:
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
            status == CallSessionState.onCall &&
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
