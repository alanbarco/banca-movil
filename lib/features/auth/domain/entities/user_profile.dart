import 'package:equatable/equatable.dart';

import 'interest.dart';
import 'segment.dart';

/// Perfil del cliente (`users/{uid}`).
class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.segment,
    required this.interests,
    this.notificationsEnabled = false,
    this.termsVersion,
    this.termsAcceptedAt,
    this.createdAt,
  });

  final String uid;
  final String fullName;
  final String email;
  final Segment segment;
  final List<Interest> interests;
  final bool notificationsEnabled;
  final String? termsVersion;

  /// `null` mientras la marca de tiempo del servidor está pendiente.
  final DateTime? termsAcceptedAt;
  final DateTime? createdAt;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  @override
  List<Object?> get props => [
    uid,
    fullName,
    email,
    segment,
    interests,
    notificationsEnabled,
    termsVersion,
    termsAcceptedAt,
    createdAt,
  ];
}
