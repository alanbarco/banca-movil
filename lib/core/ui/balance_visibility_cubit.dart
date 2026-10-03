import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/local_storage.dart';

/// Preferencia "ocultar saldos", recordada entre sesiones (FR-010).
///
/// Estado: `true` si los montos deben ocultarse.
class BalanceVisibilityCubit extends Cubit<bool> {
  BalanceVisibilityCubit(this._storage)
    : super(_storage.getBool(storageKey) ?? false);

  static const storageKey = 'hide_balances';

  final LocalStorage _storage;

  Future<void> toggle() => setHidden(hidden: !state);

  Future<void> setHidden({required bool hidden}) async {
    emit(hidden);
    await _storage.setBool(storageKey, value: hidden);
  }
}
