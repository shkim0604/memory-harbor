import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus { completed, canceled, missed, declined, failed }

CallStatus callStatusFromString(String v) {
  switch (v) {
    case 'completed':
      return CallStatus.completed;
    case 'canceled':
    case 'cancelled': // British spelling variant used by server
      return CallStatus.canceled;
    case 'missed':
      return CallStatus.missed;
    case 'declined':
      return CallStatus.declined;
    case 'failed':
      return CallStatus.failed;
    default:
      return CallStatus.failed;
  }
}

String callStatusToString(CallStatus s) {
  switch (s) {
    case CallStatus.completed:
      return 'completed';
    case CallStatus.canceled:
      return 'canceled';
    case CallStatus.missed:
      return 'missed';
    case CallStatus.declined:
      return 'declined';
    case CallStatus.failed:
      return 'failed';
  }
}

DateTime? parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}
