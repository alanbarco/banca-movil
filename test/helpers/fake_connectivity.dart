import 'dart:async';

import 'package:bi_app/core/connectivity/connectivity_status.dart';

/// Conectividad controlable desde los tests.
class FakeConnectivity implements ConnectivityStatus {
  FakeConnectivity({bool online = true}) : _online = online;

  final _changes = StreamController<bool>.broadcast(sync: true);
  bool _online;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;

  void setOnline(bool online) {
    if (online == _online) return;
    _online = online;
    _changes.add(online);
  }
}
