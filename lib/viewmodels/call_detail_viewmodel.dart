import 'dart:async';

import '../models/models.dart';
import '../services/call_service.dart';
import '../services/care_receiver_service.dart';

enum CallDetailStatus { loading, ready }

class CallDetailViewModel {
  CallDetailStatus status = CallDetailStatus.loading;
  List<String> keywords = const [];
  List<Call> previousCalls = const [];
  String receiverName = '';

  StreamSubscription<List<ResidenceStats>>? _statsSub;
  StreamSubscription<List<Call>>? _callsSub;
  StreamSubscription<CareReceiver?>? _receiverSub;
  void Function()? _onChanged;

  void init({
    required String receiverId,
    required String residenceId,
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

    _statsSub = CareReceiverService.instance
        .streamResidenceStats(receiverId)
        .listen((statsList) {
          final stats = statsList.firstWhere(
            (s) => s.residenceId == residenceId,
            orElse: () => const ResidenceStats(
              groupId: '',
              receiverId: '',
              residenceId: '',
            ),
          );
          keywords = stats.keywords;
          _onChanged?.call();
        });

    _callsSub = CallService.instance.streamCallsByReceiver(receiverId).listen((
      calls,
    ) {
      previousCalls = calls
          .where(
            (call) => call.mentionedResidences.any(
              (residence) => residence.residenceId == residenceId,
            ),
          )
          .toList();
      status = CallDetailStatus.ready;
      _onChanged?.call();
    });
  }

  void dispose() {
    _statsSub?.cancel();
    _callsSub?.cancel();
    _receiverSub?.cancel();
    _onChanged = null;
  }
}
