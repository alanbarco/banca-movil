import 'dart:math';

import 'package:bi_app/features/auth/data/datasources/customer_provisioning_datasource.dart';
import 'package:bi_app/features/auth/data/datasources/user_profile_datasource.dart';
import 'package:bi_app/features/auth/data/models/user_profile_model.dart';
import 'package:bi_app/features/auth/domain/entities/interest.dart';
import 'package:bi_app/features/auth/domain/entities/segment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth_fixtures.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late CustomerProvisioningDatasource provisioning;
  final now = DateTime.utc(2026, 10, 3, 12);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    provisioning = CustomerProvisioningDatasource(firestore, random: Random(7));
  });

  Future<void> provision() => provisioning.provision(
    uid: 'uid-ana',
    email: 'ana@bi.test',
    data: validRegistration,
    seed: contractSeed,
    now: now,
  );

  CollectionReference<Map<String, dynamic>> accounts() =>
      firestore.collection('users').doc('uid-ana').collection('accounts');

  test('crea el perfil con los campos del contrato', () async {
    await provision();

    final user = await firestore.collection('users').doc('uid-ana').get();
    final data = user.data()!;
    expect(data['fullName'], 'Ana Pérez');
    expect(data['email'], 'ana@bi.test');
    expect(data['segment'], 'student');
    expect(data['interests'], ['education', 'savings']);
    expect(data['preferences'], {'notificationsEnabled': false});
    expect(data['termsVersion'], '2026-10');
    expect(data['createdAt'], isA<Timestamp>());
    expect(data['termsAcceptedAt'], isA<Timestamp>());
    expect(data.containsKey('password'), isFalse);
  });

  test('crea una cuenta de ahorros USD con número de 10 dígitos', () async {
    await provision();

    final snapshot = await accounts().get();
    expect(snapshot.docs, hasLength(1));
    final account = snapshot.docs.single.data();
    expect(account['type'], 'savings');
    expect(account['currency'], 'USD');
    expect(account['balanceCents'], 125000);
    expect(account['number'], matches(RegExp(r'^\d{10}$')));
  });

  test(
    'crea los movimientos semilla y el más reciente cuadra con el saldo',
    () async {
      await provision();

      final account = (await accounts().get()).docs.single;
      final movements = await account.reference
          .collection('movements')
          .orderBy('date', descending: true)
          .get();
      expect(movements.docs, hasLength(3));

      final latest = movements.docs.first.data();
      expect(latest['description'], 'Supermercado');
      expect(latest['type'], 'debit');
      expect(latest['balanceAfterCents'], account.data()['balanceCents']);
      for (final doc in movements.docs) {
        final date = (doc.data()['date'] as Timestamp).toDate();
        expect(date.isBefore(now), isTrue);
      }
    },
  );

  group('UserProfileDatasource', () {
    late UserProfileDatasource profiles;

    setUp(() => profiles = UserProfileDatasource(firestore));

    test('watch emite null si no existe y el perfil cuando se crea', () async {
      final emitted = profiles.watch('uid-ana').take(2).toList();

      await Future<void>.delayed(Duration.zero);
      await provision();

      final values = await emitted;
      expect(values.first, isNull);
      expect(values.last?.segment, Segment.student);
      expect(values.last?.interests, [Interest.education, Interest.savings]);
    });

    test('actualiza intereses y notificaciones', () async {
      await provision();

      await profiles.updateInterests('uid-ana', [Interest.travel]);
      await profiles.updateNotificationsEnabled('uid-ana', enabled: true);

      final data = (await firestore.collection('users').doc('uid-ana').get())
          .data();
      expect(data!['interests'], ['travel']);
      expect(data['preferences'], {'notificationsEnabled': true});
      expect(data['updatedAt'], isA<Timestamp>());
    });
  });

  group('UserProfileModel.fromMap', () {
    test('null si faltan campos esenciales o el segmento no existe', () {
      expect(UserProfileModel.fromMap('u', null), isNull);
      expect(UserProfileModel.fromMap('u', {'fullName': 'A'}), isNull);
      expect(
        UserProfileModel.fromMap('u', {
          'fullName': 'Ana',
          'email': 'a@b.co',
          'segment': 'vip',
        }),
        isNull,
      );
    });

    test('ignora intereses desconocidos', () {
      final profile = UserProfileModel.fromMap('u', {
        'fullName': 'Ana',
        'email': 'a@b.co',
        'segment': 'professional',
        'interests': ['travel', 'crypto'],
      });

      expect(profile?.interests, [Interest.travel]);
      expect(profile?.notificationsEnabled, isFalse);
    });
  });
}
