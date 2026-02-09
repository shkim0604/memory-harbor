import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/care_receiver_service.dart';
import '../services/group_service.dart';
import '../services/user_service.dart';

enum CommunityMembersStatus {
  unauthenticated,
  loadingUser,
  loadingGroup,
  noGroup,
  loadingMembers,
  ready,
}

class CommunityMembersViewModel {
  CommunityMembersStatus status = CommunityMembersStatus.loadingUser;
  User? firebaseUser;
  AppUser? currentUser;
  Group? group;
  CareReceiver? receiver;
  List<AppUser> caregivers = const [];

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<Group?>? _groupSub;
  StreamSubscription<Group?>? _receiverGroupSub;

  int _loadToken = 0;
  bool _disposed = false;

  void init({required void Function() onChanged}) {
    firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      status = CommunityMembersStatus.unauthenticated;
      onChanged();
      return;
    }

    status = CommunityMembersStatus.loadingUser;
    onChanged();

    _userSub = UserService.instance
        .streamUser(firebaseUser!.uid)
        .listen((nextUser) {
      currentUser = nextUser;
      if (nextUser == null || nextUser.groupIds.isEmpty) {
        _subscribeGroupByReceiver(firebaseUser!.uid, onChanged);
        return;
      }

      _subscribeGroup(nextUser.groupIds.first, onChanged);
    });
  }

  void dispose() {
    _disposed = true;
    _loadToken++;
    _userSub?.cancel();
    _groupSub?.cancel();
    _receiverGroupSub?.cancel();
  }

  void _subscribeGroup(String groupId, void Function() onChanged) {
    _groupSub?.cancel();
    _receiverGroupSub?.cancel();
    status = CommunityMembersStatus.loadingGroup;
    onChanged();

    _groupSub = GroupService.instance.streamGroup(groupId).listen((nextGroup) {
      if (nextGroup == null) {
        status = CommunityMembersStatus.loadingGroup;
        onChanged();
        return;
      }

      _loadMembers(nextGroup, onChanged);
    });
  }

  void _subscribeGroupByReceiver(String receiverId, void Function() onChanged) {
    _groupSub?.cancel();
    _receiverGroupSub?.cancel();
    status = CommunityMembersStatus.loadingGroup;
    onChanged();

    _receiverGroupSub = GroupService.instance
        .streamGroupByReceiverId(receiverId)
        .listen((nextGroup) {
      if (nextGroup == null) {
        group = null;
        receiver = null;
        caregivers = const [];
        status = CommunityMembersStatus.noGroup;
        onChanged();
        return;
      }

      _loadMembers(nextGroup, onChanged);
    });
  }

  Future<void> _loadMembers(Group nextGroup, void Function() onChanged) async {
    final token = ++_loadToken;
    group = nextGroup;
    status = CommunityMembersStatus.loadingMembers;
    onChanged();

    final receiverFuture =
        CareReceiverService.instance.getReceiver(nextGroup.receiverId);
    final caregiversFuture = Future.wait<AppUser?>(
      nextGroup.careGiverUserIds.map(UserService.instance.getUser),
    );

    final nextReceiver = await receiverFuture;
    final nextCaregivers = await caregiversFuture;

    if (_disposed || token != _loadToken) return;

    receiver = nextReceiver;
    final filtered = nextCaregivers.whereType<AppUser>().toList();
    final me = currentUser;
    if (me != null && !filtered.any((user) => user.uid == me.uid)) {
      filtered.insert(0, me);
    }
    filtered.sort((a, b) => a.name.compareTo(b.name));
    caregivers = filtered;
    status = CommunityMembersStatus.ready;
    onChanged();
  }
}
