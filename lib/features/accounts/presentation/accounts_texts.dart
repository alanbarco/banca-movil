import '../../../core/error/failure.dart';
import '../domain/entities/account.dart';

abstract final class AccountsTexts {
  static const accountsTitle = 'Mis cuentas';
  static const movementsTitle = 'Movimientos';
  static const availableBalance = 'Saldo disponible';
  static const noAccounts = 'Aún no tienes cuentas abiertas.';
  static const noMovements = 'Aún no tienes movimientos en esta cuenta.';
  static const loadingAccounts = 'Cargando cuentas';
  static const loadingMovements = 'Cargando movimientos';
  static const loadingMore = 'Cargando más movimientos';
  static const loadMore = 'Ver más movimientos';
  static const loadMoreFailed = 'No pudimos cargar más movimientos.';
  static const endOfList = 'No hay más movimientos';
  static const showBalances = 'Mostrar saldos';
  static const hideBalances = 'Ocultar saldos';
  static const credit = 'Ingreso';
  static const debit = 'Egreso';

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String typeLabel(AccountType type) => switch (type) {
    AccountType.savings => 'Cuenta de ahorros',
    AccountType.checking => 'Cuenta corriente',
  };

  /// Lectura accesible del número enmascarado ("•••• 7890").
  static String maskedNumberLabel(Account account) =>
      'terminada en ${account.lastFour.split('').join(' ')}';

  /// "3 oct 2026", en hora local. Sin depender de los datos de fecha de
  /// `intl` (no se cargan en tests ni antes de las localizaciones).
  static String date(DateTime value) {
    final local = value.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  static String loadError(Failure failure) => switch (failure) {
    NetworkFailure() || TimeoutFailure() =>
      'No pudimos conectarnos. Revisa tu conexión e inténtalo de nuevo.',
    NotFoundFailure() => 'No encontramos esta cuenta.',
    UnauthorizedFailure() =>
      'Tu sesión ya no es válida. Vuelve a iniciar sesión.',
    _ => 'No pudimos cargar la información. Inténtalo de nuevo.',
  };

  /// Reintentar no ayuda si la cuenta no existe o la sesión no es válida.
  static bool isRetryable(Failure failure) =>
      failure is! NotFoundFailure && failure is! UnauthorizedFailure;
}
