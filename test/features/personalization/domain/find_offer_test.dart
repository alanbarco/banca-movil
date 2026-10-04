import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/features/personalization/domain/entities/home_layout.dart';
import 'package:bi_app/features/personalization/domain/repositories/home_layout_repository.dart';
import 'package:bi_app/features/personalization/domain/usecases/find_offer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../personalization_fixtures.dart';

class _Repository implements HomeLayoutRepository {
  _Repository({this.current});

  @override
  HomeLayout? current;

  @override
  final HomeLayout localDefaults = layoutOf({
    'default': [
      offers('local', 0, [offerItem('solo_local')]),
    ],
  });

  @override
  Stream<Result<HomeLayout>> watchLayout() => const Stream.empty();

  @override
  Future<Result<void>> refresh() async => const Success(null);
}

void main() {
  final remote = layoutOf({
    'student': [
      offers('ofertas', 0, [offerItem('beca')]),
    ],
  });

  test('encuentra la oferta del layout vigente del segmento', () {
    final offer = FindOffer(_Repository(current: remote))(
      'beca',
      segment: 'student',
    );

    expect(offer?.title, 'Oferta beca');
    expect(offer?.description, 'Descripción beca');
  });

  test('oferta retirada por el banco → null (no usa los defaults)', () {
    final offer = FindOffer(_Repository(current: remote))(
      'solo_local',
      segment: 'student',
    );

    expect(offer, isNull);
  });

  test('sin layout remoto usa los defaults locales', () {
    final offer = FindOffer(_Repository())('solo_local', segment: 'student');

    expect(offer?.id, 'solo_local');
  });
}
