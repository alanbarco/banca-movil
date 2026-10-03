import 'package:bi_app/features/auth/domain/entities/interest.dart';
import 'package:bi_app/features/auth/domain/entities/onboarding_seed.dart';
import 'package:bi_app/features/auth/domain/entities/registration_data.dart';
import 'package:bi_app/features/auth/domain/entities/segment.dart';
import 'package:bi_app/features/auth/domain/entities/user_profile.dart';

const validRegistration = RegistrationData(
  fullName: 'Ana Pérez',
  email: 'ana@bi.test',
  password: 'secreta123',
  segment: Segment.student,
  interests: [Interest.education, Interest.savings],
  termsAccepted: true,
  termsVersion: '2026-10',
);

const anaProfile = UserProfile(
  uid: 'uid-ana',
  fullName: 'Ana Pérez',
  email: 'ana@bi.test',
  segment: Segment.student,
  interests: [Interest.education],
);

/// Semilla del contrato (`contracts/remote-config.md`).
const contractSeedJson = <String, dynamic>{
  'schemaVersion': 1,
  'account': {'type': 'savings', 'initialBalanceCents': 125000},
  'movements': [
    {
      'description': 'Depósito de apertura',
      'amountCents': 100000,
      'type': 'credit',
      'daysAgo': 10,
    },
    {
      'description': 'Transferencia recibida',
      'amountCents': 40000,
      'type': 'credit',
      'daysAgo': 6,
    },
    {
      'description': 'Supermercado',
      'amountCents': 15000,
      'type': 'debit',
      'daysAgo': 3,
    },
  ],
};

final contractSeed = OnboardingSeed.fromJson(contractSeedJson)!;
