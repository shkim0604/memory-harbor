import 'dart:async';

import '../models/models.dart';
import '../services/call_service.dart';

class HistoryDetailViewModel {
  List<Call> filteredCalls = const [];
  StreamSubscription<List<Call>>? _callsSub;
  void Function()? _onChanged;

  void init({
    required String receiverId,
    required String residenceId,
    required void Function() onChanged,
  }) {
    _onChanged = onChanged;
    _callsSub = CallService.instance
        .streamCallsByReceiver(receiverId)
        .listen((calls) {
      filteredCalls = calls
          .where(
            (call) => call.mentionedResidences.any(
              (residence) => residence.residenceId == residenceId,
            ),
          )
          .toList();
      _onChanged?.call();
    });
  }

  void dispose() {
    _callsSub?.cancel();
    _onChanged = null;
  }
}
