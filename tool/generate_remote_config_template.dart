// Genera la plantilla de Remote Config a partir de los defaults locales, para
// que la app y la consola partan de los mismos valores (FR-017).
//
// Uso: dart run tool/generate_remote_config_template.dart
// Luego: firebase deploy --only remoteconfig
import 'dart:convert';
import 'dart:io';

const defaultsPath = 'assets/config/remote_config_defaults.json';
const templatePath = 'firebase/remoteconfig.template.json';

const _descriptions = {
  'home_layout':
      'Layout SDUI del inicio por segmento (contracts/remote-config.md).',
  'feature_flags': 'Flags de funcionalidades con segmentación.',
  'onboarding_seed': 'Cuenta y movimientos iniciales creados en el onboarding.',
  'fx_config': 'Configuración del servicio externo de divisas.',
  'terms': 'Versión y URL de los términos y condiciones vigentes.',
};

/// Plantilla en el formato que espera `firebase deploy --only remoteconfig`.
Map<String, Object> buildTemplate(Map<String, dynamic> defaults) {
  return {
    'conditions': <Object>[],
    'parameters': {
      for (final entry in defaults.entries)
        entry.key: {
          'defaultValue': {'value': jsonEncode(entry.value)},
          'valueType': 'JSON',
          if (_descriptions[entry.key] case final description?)
            'description': description,
        },
    },
    'parameterGroups': <String, Object>{},
  };
}

String renderTemplate(String defaultsJson) {
  final defaults = jsonDecode(defaultsJson) as Map<String, dynamic>;
  return '${const JsonEncoder.withIndent('  ').convert(buildTemplate(defaults))}\n';
}

void main() {
  final output = renderTemplate(File(defaultsPath).readAsStringSync());
  File(templatePath).writeAsStringSync(output);
  stdout.writeln('Plantilla generada en $templatePath');
}
