import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../utils/time_utils.dart';

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
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final dateText = _formatDate(call.startedAt);
    final durationText = _formatDuration(call.durationSec);
    final name =
        call.giverNameSnapshot.isNotEmpty ? call.giverNameSnapshot : '통화 상대';

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
              color: AppColors.primaryLight.withValues(alpha: 0.35),
            ),
            child: const Icon(Icons.call, color: AppColors.primary),
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

  String _formatDate(DateTime date) {
    final et = TimeUtils.toEt(date);
    final year = et.year.toString();
    final month = et.month.toString().padLeft(2, '0');
    final day = et.day.toString().padLeft(2, '0');
    final hour = et.hour.toString().padLeft(2, '0');
    final minute = et.minute.toString().padLeft(2, '0');
    return '$year.$month.$day $hour:$minute';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '0분';
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    if (minutes <= 0) return '${remain}초';
    return remain == 0 ? '${minutes}분' : '${minutes}분 ${remain}초';
  }
}
