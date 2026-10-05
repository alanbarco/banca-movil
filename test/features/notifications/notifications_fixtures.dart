import 'package:bi_app/core/session/current_user_profile.dart';
import 'package:bi_app/core/session/session_status.dart';

class FakeSession implements SessionStatusSource {
  FakeSession([this.status = SessionStatus.authenticated]);

  @override
  SessionStatus status;

  @override
  Stream<SessionStatus> get changes => const Stream.empty();
}

class FakeProfile implements CurrentUserProfile {
  FakeProfile([this.current]);

  @override
  SessionUser? current;

  @override
  Stream<SessionUser?> get user => Stream.value(current);
}

const ana = SessionUser(
  uid: 'uid-ana',
  segment: 'student',
  notificationsEnabled: true,
);
