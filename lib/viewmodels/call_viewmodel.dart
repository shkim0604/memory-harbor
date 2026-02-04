import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/care_receiver_service.dart';
import '../services/group_service.dart';
import '../services/user_service.dart';

enum CallDataStatus {
  unauthenticated,
  loadingUser,
  noGroup,
  loadingGroup,
  loadingReceiver,
  loadingStats,
  ready,
}

class CallViewModel {
  CallDataStatus status = CallDataStatus.loadingUser;
  User? firebaseUser;
  AppUser? user;
  Group? group;
  CareReceiver? receiver;
  List<ResidenceStats> statsList = const [];

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<Group?>? _groupSub;
  StreamSubscription<CareReceiver?>? _receiverSub;
  StreamSubscription<List<ResidenceStats>>? _statsSub;

  void Function()? _onChanged;

  void init({required void Function() onChanged}) {
    _onChanged = onChanged;
    firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      status = CallDataStatus.unauthenticated;
      _onChanged?.call();
      return;
    }

    status = CallDataStatus.loadingUser;
    _onChanged?.call();

    _userSub = UserService.instance
        .streamUser(firebaseUser!.uid)
        .listen((nextUser) {
      user = nextUser;
      if (nextUser == null) {
        status = CallDataStatus.loadingUser;
        _onChanged?.call();
        return;
      }

      if (nextUser.groupIds.isEmpty) {
        _clearGroupState();
        status = CallDataStatus.noGroup;
        _onChanged?.call();
        return;
      }

      _subscribeGroup(nextUser.groupIds.first);
    });
  }

  void dispose() {
    _userSub?.cancel();
    _groupSub?.cancel();
    _receiverSub?.cancel();
    _statsSub?.cancel();
    _onChanged = null;
  }

  void _subscribeGroup(String groupId) {
    _groupSub?.cancel();
    status = CallDataStatus.loadingGroup;
    _onChanged?.call();

    _groupSub = GroupService.instance.streamGroup(groupId).listen((nextGroup) {
      group = nextGroup;
      if (nextGroup == null) {
        status = CallDataStatus.loadingGroup;
        _onChanged?.call();
        return;
      }

      _subscribeReceiver(nextGroup.receiverId);
    });
  }

  void _subscribeReceiver(String receiverId) {
    _receiverSub?.cancel();
    status = CallDataStatus.loadingReceiver;
    _onChanged?.call();

    _receiverSub = CareReceiverService.instance
        .streamReceiver(receiverId)
        .listen((nextReceiver) {
      receiver = nextReceiver;
      if (nextReceiver == null) {
        status = CallDataStatus.loadingReceiver;
        _onChanged?.call();
        return;
      }

      _subscribeResidenceStats(nextReceiver.receiverId);
    });
  }

  void _subscribeResidenceStats(String receiverId) {
    _statsSub?.cancel();
    status = CallDataStatus.loadingStats;
    _onChanged?.call();

    _statsSub = CareReceiverService.instance
        .streamResidenceStats(receiverId)
        .listen((nextStats) {
      statsList = nextStats;
      status = CallDataStatus.ready;
      _onChanged?.call();
    });
  }

  void _clearGroupState() {
    group = null;
    receiver = null;
    statsList = const [];
    _groupSub?.cancel();
    _receiverSub?.cancel();
    _statsSub?.cancel();
  }
}
