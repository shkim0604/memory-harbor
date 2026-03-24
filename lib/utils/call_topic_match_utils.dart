import '../models/call.dart';

class CallTopicMatchUtils {
  CallTopicMatchUtils._();

  static bool matchesResidence(Call call, String residenceId) {
    final normalizedResidenceId = residenceId.trim();
    if (normalizedResidenceId.isEmpty) return false;

    if (call.selectedResidenceId.trim() == normalizedResidenceId) {
      return true;
    }

    if (call.selectedTopicType == 'residence' &&
        call.selectedTopicId.trim() == normalizedResidenceId) {
      return true;
    }

    return call.mentionedResidences.any(
      (residence) => residence.residenceId.trim() == normalizedResidenceId,
    );
  }

  static bool matchesMeaning(Call call, String meaningId) {
    final normalizedMeaningId = meaningId.trim();
    if (normalizedMeaningId.isEmpty) return false;

    if (call.selectedMeaningId.trim() == normalizedMeaningId) {
      return true;
    }

    return call.selectedTopicType == 'meaning' &&
        call.selectedTopicId.trim() == normalizedMeaningId;
  }
}
