import 'dart:async';

import '../models/models.dart';
import '../services/call_service.dart';
import '../utils/call_topic_match_utils.dart';

enum HistoryDetailTopicType { residence, meaning }

class HistoryDetailViewModel {
  List<Call> filteredCalls = const [];
  StreamSubscription<List<Call>>? _callsSub;
  void Function()? _onChanged;

  void init({
    required String receiverId,
    required String topicId,
    required HistoryDetailTopicType topicType,
    required void Function() onChanged,
  }) {
    _onChanged = onChanged;
    _callsSub = CallService.instance.streamCallsByReceiver(receiverId).listen((
      calls,
    ) {
      filteredCalls = calls.where((call) {
        if (topicType == HistoryDetailTopicType.residence) {
          return CallTopicMatchUtils.matchesResidence(call, topicId);
        }
        return CallTopicMatchUtils.matchesMeaning(call, topicId);
      }).toList();
      _onChanged?.call();
    });
  }

  void dispose() {
    _callsSub?.cancel();
    _onChanged = null;
  }
}
