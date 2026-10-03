// Verifica la cobertura mínima de líneas exigida por la constitución (Principio V):
// solo cuenta archivos de las capas `domain` y `presentation/bloc`.
//
// Uso: flutter test --coverage && dart run tool/check_coverage.dart [umbral]
import 'dart:io';

const _defaultThreshold = 70.0;
const _lcovPath = 'coverage/lcov.info';

bool _isTracked(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return normalized.contains('/domain/') ||
      normalized.contains('/presentation/bloc/');
}

void main(List<String> args) {
  final threshold = args.isNotEmpty
      ? double.parse(args.first)
      : _defaultThreshold;
  final file = File(_lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('No existe $_lcovPath. Ejecuta: flutter test --coverage');
    exit(1);
  }

  var found = 0;
  var hit = 0;
  var files = 0;
  String? current;

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3);
    } else if (line.startsWith('DA:') &&
        current != null &&
        _isTracked(current)) {
      found++;
      final count = int.parse(line.substring(3).split(',')[1]);
      if (count > 0) hit++;
    } else if (line == 'end_of_record') {
      if (current != null && _isTracked(current)) files++;
      current = null;
    }
  }

  if (found == 0) {
    stdout.writeln('Sin archivos de domain/bloc todavía; se omite el umbral.');
    return;
  }

  final pct = hit * 100 / found;
  stdout.writeln(
    'Cobertura domain + presentation/bloc: ${pct.toStringAsFixed(1)}% '
    '($hit/$found líneas, $files archivos). Umbral: $threshold%',
  );
  if (pct < threshold) {
    stderr.writeln('Cobertura por debajo del umbral.');
    exit(1);
  }
}
