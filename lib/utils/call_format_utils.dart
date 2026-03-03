import '../models/call.dart';
import 'time_utils.dart';

/// UI에서 공통으로 쓰는 통화 시간/날짜 포맷 유틸.
/// 콜 비즈니스 로직과 분리해 화면 코드의 중복을 줄인다.
class CallFormatUtils {
  CallFormatUtils._();

  static String formatDateTimeEt(DateTime dateTime) {
    final et = TimeUtils.toEt(dateTime);
    final year = et.year.toString();
    final month = et.month.toString().padLeft(2, '0');
    final day = et.day.toString().padLeft(2, '0');
    final hour = et.hour.toString().padLeft(2, '0');
    final minute = et.minute.toString().padLeft(2, '0');
    return '$year.$month.$day $hour:$minute';
  }

  static String formatDurationCompact(Call call) {
    final seconds = durationSeconds(call);
    if (seconds <= 0) return '0초';
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    if (minutes <= 0) return '$seconds초';
    return remain == 0 ? '$minutes분' : '$minutes분 $remain초';
  }

  static String formatDurationHumanized(Call call) {
    final seconds = durationSeconds(call);
    if (seconds <= 0) return '0초';
    final duration = Duration(seconds: seconds);
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 60) {
      if (totalMinutes <= 0) return '$seconds초';
      return '$totalMinutes분';
    }
    final hours = duration.inHours;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return '$hours시간';
    }
    return '$hours시간 $minutes분';
  }

  static int durationSeconds(Call call) {
    final raw = call.durationSec ?? 0;
    if (raw > 0) return raw;
    final endedAt = call.endedAt;
    if (endedAt == null) return 0;
    final diff = endedAt.difference(call.startedAt).inSeconds;
    return diff > 0 ? diff : 0;
  }
}
