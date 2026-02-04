import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/call_service.dart';
import '../services/group_service.dart';

enum ReceiverHomeStatus {
  unauthenticated,
  loadingGroup,
  noGroup,
  ready,
}

class ReceiverHomeViewModel {
  ReceiverHomeStatus status = ReceiverHomeStatus.loadingGroup;
  User? firebaseUser;
  Group? group;
  List<Call> calls = const [];

  StreamSubscription<Group?>? _groupSub;
  StreamSubscription<List<Call>>? _callsSub;

  void init({required void Function() onChanged}) {
    firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      status = ReceiverHomeStatus.unauthenticated;
      onChanged();
      return;
    }

    status = ReceiverHomeStatus.loadingGroup;
    onChanged();

    _groupSub?.cancel();
    _groupSub = GroupService.instance
        .streamGroupByReceiverId(firebaseUser!.uid)
        .listen((nextGroup) {
      group = nextGroup;
      if (nextGroup == null) {
        calls = const [];
        status = ReceiverHomeStatus.noGroup;
        _callsSub?.cancel();
        onChanged();
        return;
      }

      _subscribeCalls(nextGroup.receiverId, onChanged);
    });
  }

  void dispose() {
    _groupSub?.cancel();
    _callsSub?.cancel();
  }

  void _subscribeCalls(String receiverId, void Function() onChanged) {
    _callsSub?.cancel();
    _callsSub = CallService.instance
        .streamCallsByReceiver(receiverId)
        .listen((nextCalls) {
      calls = nextCalls;
      status = ReceiverHomeStatus.ready;
      onChanged();
    });
  }

  int get thisWeekCalls {
    final now = DateTime.now();
    return calls
        .where(
          (call) =>
              call.startedAt.isAfter(now.subtract(const Duration(days: 7))),
        )
        .length;
  }
}
