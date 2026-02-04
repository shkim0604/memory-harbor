import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/care_receiver_service.dart';
import '../services/group_service.dart';
import '../services/user_service.dart';

enum HistoryStatus {
  unauthenticated,
  loadingUser,
  noGroup,
  loadingGroup,
  loadingReceiver,
  loadingStats,
  ready,
}

class HistoryViewModel {
  HistoryStatus status = HistoryStatus.loadingUser;
  User? firebaseUser;
  Group? group;
  CareReceiver? receiver;
  List<ResidenceStats> statsList = const [];

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<Group?>? _groupSub;
  StreamSubscription<CareReceiver?>? _receiverSub;
  StreamSubscription<List<ResidenceStats>>? _statsSub;

  void init({required void Function() onChanged}) {
    firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      status = HistoryStatus.unauthenticated;
      onChanged();
      return;
    }

    status = HistoryStatus.loadingUser;
    onChanged();

    _userSub = UserService.instance
        .streamUser(firebaseUser!.uid)
        .listen((nextUser) {
      if (nextUser == null) {
        status = HistoryStatus.loadingUser;
        onChanged();
        return;
      }

      if (nextUser.groupIds.isEmpty) {
        _clearGroupState();
        status = HistoryStatus.noGroup;
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
    _statsSub?.cancel();
  }

  void _subscribeGroup(String groupId, void Function() onChanged) {
    _groupSub?.cancel();
    status = HistoryStatus.loadingGroup;
    onChanged();

    _groupSub = GroupService.instance.streamGroup(groupId).listen((nextGroup) {
      group = nextGroup;
      if (nextGroup == null) {
        status = HistoryStatus.loadingGroup;
        onChanged();
        return;
      }

      _subscribeReceiver(nextGroup.receiverId, onChanged);
    });
  }

  void _subscribeReceiver(String receiverId, void Function() onChanged) {
    _receiverSub?.cancel();
    status = HistoryStatus.loadingReceiver;
    onChanged();

    _receiverSub = CareReceiverService.instance
        .streamReceiver(receiverId)
        .listen((nextReceiver) {
      receiver = nextReceiver;
      if (nextReceiver == null) {
        status = HistoryStatus.loadingReceiver;
        onChanged();
        return;
      }

      _subscribeResidenceStats(nextReceiver.receiverId, onChanged);
    });
  }

  void _subscribeResidenceStats(String receiverId, void Function() onChanged) {
    _statsSub?.cancel();
    status = HistoryStatus.loadingStats;
    onChanged();

    _statsSub = CareReceiverService.instance
        .streamResidenceStats(receiverId)
        .listen((nextStats) {
      statsList = nextStats;
      status = HistoryStatus.ready;
      onChanged();
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
