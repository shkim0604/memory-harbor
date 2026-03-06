import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/call_service.dart';
import '../services/group_service.dart';
import '../services/user_service.dart';
import '../utils/time_utils.dart';

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
  int caregiverCount = 0;

  StreamSubscription<Group?>? _groupSub;
  StreamSubscription<List<Call>>? _callsSub;
  StreamSubscription<List<AppUser>>? _membersSub;

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
        caregiverCount = 0;
        status = ReceiverHomeStatus.noGroup;
        _callsSub?.cancel();
        _membersSub?.cancel();
        onChanged();
        return;
      }

      _subscribeCalls(nextGroup.groupId, onChanged);
      _subscribeMembers(nextGroup, onChanged);
    });
  }

  void dispose() {
    _groupSub?.cancel();
    _callsSub?.cancel();
    _membersSub?.cancel();
  }

  void _subscribeCalls(String groupId, void Function() onChanged) {
    _callsSub?.cancel();
    _callsSub = CallService.instance
        .streamCallsByGroup(groupId)
        .listen((nextCalls) {
      calls = nextCalls;
      status = ReceiverHomeStatus.ready;
      onChanged();
    });
  }

  void _subscribeMembers(Group group, void Function() onChanged) {
    _membersSub?.cancel();
    _membersSub = UserService.instance
        .streamUsersByGroupId(group.groupId)
        .listen((users) {
      caregiverCount = users.where((user) => user.uid != group.receiverId).length;
      if (status != ReceiverHomeStatus.noGroup) {
        status = ReceiverHomeStatus.ready;
      }
      onChanged();
    });
  }

  int get thisWeekCalls {
    final now = TimeUtils.nowEt();
    return completedCalls
        .where(
          (call) =>
              call.startedAt.isAfter(now.subtract(const Duration(days: 7))),
        )
        .length;
  }

  List<Call> get completedCalls => calls
      .where((call) => call.endedAt != null && (call.durationSec ?? 0) > 0)
      .toList();

  int get totalCompletedCalls => completedCalls.length;

  List<Call> get displayCalls => calls;

  List<Call> visibleCalls(int maxCount) {
    if (maxCount <= 0) return const [];
    return displayCalls.take(maxCount).toList();
  }

  bool hasMoreCalls(int maxCount) {
    if (maxCount <= 0) return calls.isNotEmpty;
    return displayCalls.length > maxCount;
  }
}
