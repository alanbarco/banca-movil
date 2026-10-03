import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_remote_config_template.dart';

void main() {
  test('la plantilla de Remote Config coincide con los defaults locales', () {
    final expected = renderTemplate(File(defaultsPath).readAsStringSync());
    final actual = File(templatePath).readAsStringSync();

    expect(
      actual.replaceAll('\r\n', '\n'),
      expected,
      reason:
          'Ejecuta: dart run tool/generate_remote_config_template.dart '
          '(el asset y la plantilla deben tener los mismos valores).',
    );
  });
}
