import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../utils/call_format_utils.dart';

class ReceiverCallHistoryScreen extends StatelessWidget {
  final List<Call> calls;

  const ReceiverCallHistoryScreen({super.key, required this.calls});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('나의 통화기록'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: calls.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final call = calls[index];
          return _ReceiverCallHistoryCard(call: call);
        },
      ),
    );
  }
}

class _ReceiverCallHistoryCard extends StatelessWidget {
  final Call call;

  const _ReceiverCallHistoryCard({required this.call});

  @override
  Widget build(BuildContext context) {
    final dateText = CallFormatUtils.formatDateTimeEt(call.startedAt);
    final durationText = CallFormatUtils.formatDurationCompact(call);
    final name =
        call.giverNameSnapshot.isNotEmpty ? call.giverNameSnapshot : '통화 상대';
    final isCompleted = call.endedAt != null && (call.durationSec ?? 0) > 0;
    final icon = isCompleted ? Icons.call : Icons.phone_missed;
    final iconColor = AppColors.primary;
    final bubbleColor = AppColors.primaryLight.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bubbleColor,
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            durationText,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
