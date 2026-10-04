import 'package:equatable/equatable.dart';

/// Parámetro `fx_config` de Remote Config (`contracts/remote-config.md`).
/// Campos ausentes o inválidos caen al valor por defecto.
class FxConfig extends Equatable {
  const FxConfig({
    this.baseUrl = defaultBaseUrl,
    this.base = 'USD',
    this.symbols = defaultSymbols,
    this.timeout = const Duration(milliseconds: 8000),
  });

  factory FxConfig.fromJson(Map<String, dynamic> json) {
    final baseUrl = json['baseUrl'];
    final base = json['base'];
    final symbols = json['symbols'];
    final timeoutMs = json['timeoutMs'];
    return FxConfig(
      baseUrl: baseUrl is String && baseUrl.startsWith('https://')
          ? baseUrl
          : defaultBaseUrl,
      base: base is String && base.isNotEmpty ? base : 'USD',
      symbols: symbols is List && symbols.isNotEmpty
          ? symbols.whereType<String>().toList()
          : defaultSymbols,
      timeout: timeoutMs is int && timeoutMs > 0
          ? Duration(milliseconds: timeoutMs)
          : const Duration(milliseconds: 8000),
    );
  }

  static const defaultBaseUrl = 'https://api.frankfurter.dev/v1';
  static const defaultSymbols = [
    'EUR',
    'MXN',
    'BRL',
    'GBP',
    'JPY',
    'CAD',
    'CNY',
  ];

  final String baseUrl;
  final String base;
  final List<String> symbols;
  final Duration timeout;

  @override
  List<Object?> get props => [baseUrl, base, symbols, timeout];
}
