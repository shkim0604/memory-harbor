import 'dart:async';

import '../models/models.dart';
import '../services/call_service.dart';
import '../services/care_receiver_service.dart';

enum CallDetailStatus { loading, ready }

class CallDetailViewModel {
  CallDetailStatus status = CallDetailStatus.loading;
  List<Call> previousCalls = const [];
  String receiverName = '';

  StreamSubscription<List<Call>>? _callsSub;
  StreamSubscription<CareReceiver?>? _receiverSub;
  void Function()? _onChanged;

  void init({
    required String receiverId,
    required String topicType,
    required String topicId,
    required void Function() onChanged,
  }) {
    _onChanged = onChanged;

    // Load receiver name.
    _receiverSub = CareReceiverService.instance
        .streamReceiver(receiverId)
        .listen((receiver) {
          receiverName = receiver?.name ?? '';
          _onChanged?.call();
        });

    _callsSub = CallService.instance.streamCallsByReceiver(receiverId).listen((
      calls,
    ) {
      previousCalls = calls.where((call) {
        if (topicType == 'meaning') {
          return call.selectedMeaningId == topicId ||
              (call.selectedTopicType == 'meaning' &&
                  call.selectedTopicId == topicId);
        }
        return call.mentionedResidences.any(
          (residence) => residence.residenceId == topicId,
        );
      }).toList();
      status = CallDetailStatus.ready;
      _onChanged?.call();
    });
  }

  void dispose() {
    _callsSub?.cancel();
    _receiverSub?.cancel();
    _onChanged = null;
  }
}
