import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/group_service.dart';
import '../services/user_service.dart';

enum AppRoleStatus {
  unauthenticated,
  loading,
  noGroup,
  ready,
}

enum AppRole { caregiver, receiver }

class AppRoleViewModel {
  AppRoleStatus status = AppRoleStatus.loading;
  AppRole role = AppRole.caregiver;
  User? firebaseUser;
  AppUser? user;
  Group? group;

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<Group?>? _userGroupSub;
  StreamSubscription<Group?>? _receiverGroupSub;

  Group? _groupFromUser;
  Group? _groupFromReceiver;

  void Function()? _onChanged;

  void init({required void Function() onChanged}) {
    _onChanged = onChanged;
    firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      status = AppRoleStatus.unauthenticated;
      _onChanged?.call();
      return;
    }

    status = AppRoleStatus.loading;
    _onChanged?.call();

    _receiverGroupSub?.cancel();
    _receiverGroupSub = GroupService.instance
        .streamGroupByReceiverId(firebaseUser!.uid)
        .listen((nextGroup) {
      _groupFromReceiver = nextGroup;
      _refreshRole();
    });

    _userSub?.cancel();
    _userSub = UserService.instance
        .streamUser(firebaseUser!.uid)
        .listen((nextUser) {
      user = nextUser;
      if (nextUser == null) {
        _groupFromUser = null;
        _userGroupSub?.cancel();
        _refreshRole();
        return;
      }

      if (nextUser.groupIds.isEmpty) {
        _groupFromUser = null;
        _userGroupSub?.cancel();
        _refreshRole();
        return;
      }

      _subscribeUserGroup(nextUser.groupIds.first);
    });
  }

  void dispose() {
    _userSub?.cancel();
    _userGroupSub?.cancel();
    _receiverGroupSub?.cancel();
    _onChanged = null;
  }

  void _subscribeUserGroup(String groupId) {
    _userGroupSub?.cancel();
    _userGroupSub = GroupService.instance
        .streamGroup(groupId)
        .listen((nextGroup) {
      _groupFromUser = nextGroup;
      _refreshRole();
    });
  }

  void _refreshRole() {
    if (firebaseUser == null) {
      status = AppRoleStatus.unauthenticated;
      _onChanged?.call();
      return;
    }

    if (_groupFromReceiver != null) {
      role = AppRole.receiver;
      group = _groupFromReceiver;
      status = AppRoleStatus.ready;
      _onChanged?.call();
      return;
    }

    if (_groupFromUser != null) {
      role = AppRole.caregiver;
      group = _groupFromUser;
      status = AppRoleStatus.ready;
      _onChanged?.call();
      return;
    }

    if (user == null) {
      status = AppRoleStatus.loading;
      _onChanged?.call();
      return;
    }

    status = AppRoleStatus.noGroup;
    _onChanged?.call();
  }
}
