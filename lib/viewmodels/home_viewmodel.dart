import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/call_service.dart';
import '../services/care_receiver_service.dart';
import '../services/group_service.dart';
import '../services/user_service.dart';
import '../utils/time_utils.dart';

enum HomeStatus {
  unauthenticated,
  loadingUser,
  noGroup,
  loadingGroup,
  loadingReceiver,
  ready,
}

class HomeViewModel {
  HomeStatus status = HomeStatus.loadingUser;
  User? firebaseUser;
  AppUser? user;
  Group? group;
  CareReceiver? receiver;
  List<Call> calls = const [];

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<Group?>? _groupSub;
  StreamSubscription<CareReceiver?>? _receiverSub;
  StreamSubscription<List<Call>>? _callsSub;

  void init({required void Function() onChanged}) {
    firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      status = HomeStatus.unauthenticated;
      onChanged();
      return;
    }

    status = HomeStatus.loadingUser;
    onChanged();

    _userSub = UserService.instance
        .streamUser(firebaseUser!.uid)
        .listen((nextUser) {
      user = nextUser;
      if (nextUser == null) {
        status = HomeStatus.loadingUser;
        onChanged();
        return;
      }

      if (nextUser.groupIds.isEmpty) {
        _clearGroupState();
        status = HomeStatus.noGroup;
        onChanged();
        return;
      }

      _subscribeGroup(nextUser.groupIds.first, onChanged);
    });
  }

  void dispose() {
    _userSub?.cancel();
    _groupSub?.cancel();
    _receiverSub?.cancel();
    _callsSub?.cancel();
  }

  void _subscribeGroup(String groupId, void Function() onChanged) {
    _groupSub?.cancel();
    status = HomeStatus.loadingGroup;
    onChanged();

    _groupSub = GroupService.instance.streamGroup(groupId).listen((nextGroup) {
      group = nextGroup;
      if (nextGroup == null) {
        status = HomeStatus.loadingGroup;
        onChanged();
        return;
      }

      _subscribeReceiver(nextGroup.receiverId, onChanged);
    });
  }

  void _subscribeReceiver(String receiverId, void Function() onChanged) {
    _receiverSub?.cancel();
    status = HomeStatus.loadingReceiver;
    onChanged();

    _receiverSub = CareReceiverService.instance
        .streamReceiver(receiverId)
        .listen((nextReceiver) {
      receiver = nextReceiver;
      if (nextReceiver == null) {
        status = HomeStatus.loadingReceiver;
        onChanged();
        return;
      }

      _subscribeCalls(onChanged);
    });
  }

  void _subscribeCalls(void Function() onChanged) {
    if (group == null) return;
    _callsSub?.cancel();
    _callsSub = CallService.instance
        .streamCallsByGroup(group!.groupId)
        .listen((nextCalls) {
      calls = nextCalls;
      status = HomeStatus.ready;
      onChanged();
    });
  }

  void _clearGroupState() {
    group = null;
    receiver = null;
    calls = const [];
    _groupSub?.cancel();
    _receiverSub?.cancel();
    _callsSub?.cancel();
  }

  List<Call> get myCalls {
    if (firebaseUser == null) return const [];
    return calls
        .where((call) => call.caregiverUserId == firebaseUser!.uid)
        .toList();
  }

  List<Call> get communityCalls {
    if (firebaseUser == null) return const [];
    return calls
        .where((call) => call.caregiverUserId != firebaseUser!.uid)
        .toList();
  }

  List<Call> get sortedMyCalls => _sortCallsDesc(myCalls);

  List<Call> get sortedCommunityCalls => _sortCallsDesc(communityCalls);

  List<Call> get completedCalls => calls
      .where((call) => call.endedAt != null && (call.durationSec ?? 0) > 0)
      .toList();

  int get totalCompletedCalls => completedCalls.length;

  int get thisWeekCalls {
    final now = TimeUtils.nowEt();
    return completedCalls
        .where(
          (call) =>
              call.startedAt.isAfter(now.subtract(const Duration(days: 7))),
        )
        .length;
  }

  List<Call> recentMyCalls(int count) => _takeRecentCalls(myCalls, count);

  List<Call> recentCommunityCalls(int count) =>
      _takeRecentCalls(communityCalls, count);

  List<Call> _sortCallsDesc(List<Call> input) {
    final sorted = [...input];
    sorted.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sorted;
  }

  List<Call> _takeRecentCalls(List<Call> input, int count) {
    return _sortCallsDesc(input).take(count).toList();
  }
}
