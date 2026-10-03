import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../balance_visibility_cubit.dart';

/// Monto en USD a partir de centavos, ocultable y accesible (FR-010, FR-033).
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.cents, {
    this.style,
    this.hidden,
    this.showSign = false,
    this.textAlign,
    super.key,
  });

  static const locale = 'es_EC';
  static const hiddenMask = '••••';
  static const hiddenLabel = 'saldo oculto';

  final int cents;
  final TextStyle? style;

  /// Fuerza el estado; si es `null` se lee de `BalanceVisibilityCubit`.
  final bool? hidden;

  /// Antepone `+` o `−` (movimientos).
  final bool showSign;
  final TextAlign? textAlign;

  static String format(int cents, {bool showSign = false}) {
    // `intl` no trae datos de es_EC y cae a `es` ("1.250,00 $"); en Ecuador
    // el símbolo va delante: "$1.250,00".
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: r'$',
      decimalDigits: 2,
      customPattern: '¤#,##0.00',
    );
    final amount = formatter.format(cents.abs() / 100);
    if (!showSign) return cents < 0 ? '-$amount' : amount;
    return cents < 0 ? '−$amount' : '+$amount';
  }

  static String semanticsFor(int cents, {bool showSign = false}) {
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 2,
    ).format(cents.abs() / 100);
    final prefix = cents < 0 ? 'menos ' : (showSign ? 'más ' : '');
    return '$prefix$number dólares';
  }

  @override
  Widget build(BuildContext context) {
    final isHidden =
        hidden ?? context.select<BalanceVisibilityCubit, bool>((c) => c.state);
    return Semantics(
      label: isHidden ? hiddenLabel : semanticsFor(cents, showSign: showSign),
      excludeSemantics: true,
      child: Text(
        isHidden ? hiddenMask : format(cents, showSign: showSign),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
