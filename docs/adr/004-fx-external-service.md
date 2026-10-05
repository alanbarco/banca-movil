# ADR-004: Tipos de cambio con Frankfurter como servicio externo

- **Estado**: aceptada · 2026-10-03
- **Fuente**: [research.md R5](../../specs/001-digital-banking-mvp/research.md) ·
  [fx-external-api.md](../../specs/001-digital-banking-mvp/contracts/fx-external-api.md)

## Problema

Los requerimientos de la aplicación piden integrar al menos un servicio o micro aplicativo externo relevante para el
ecosistema, y demostrar el comportamiento cuando ese servicio falla sin afectar al resto.

## Alternativas evaluadas

| Opción | En contra |
|---|---|
| **Frankfurter** (tasas del BCE, sin API key) | No incluye algunas divisas latinoamericanas (COP, PEN) |
| Micro-app web en WebView | Más "micro-frontend", pero más tiempo, peor accesibilidad y testabilidad |
| APIs con key gratuita | Fricción de registro y un secreto que no puede vivir en la app |

## Decisión

- `FxRemoteDatasource` hace `GET {baseUrl}/latest?base=USD&symbols=…` con **dio**. La URL,
  la base, las divisas y el timeout vienen de Remote Config (`fx_config`), validados con
  valores seguros por defecto (solo `https://`).
- `DioFactory` agrega a todo cliente HTTP: timeout, `RetryInterceptor` (3 reintentos con
  backoff 0,5 s → 1 s → 2 s, **solo GET**, solo ante timeout, error de conexión o 5xx) y el
  interceptor del simulador de fallos.
- `FxRepositoryImpl`: respuesta válida → se guarda en caché (`shared_preferences`); falla con
  caché → caché marcada `isStale`; falla sin caché → `Failure` con "Reintentar". Cada falla
  emite `fx_service_failure` con su causa (`timeout`, `http_5xx`, `http_4xx`, `network`,
  `invalid`).
- `ConvertCurrency` (dominio) convierte con una sola fórmula, `monto ÷ tasa(origen) ×
  tasa(destino)`, redondeo a 2 decimales (JPY a 0) y devuelve la tasa efectiva usada.

## Trade-offs

- La URL no es un secreto: la API es pública y sin key. Si un proveedor exigiera key, iría
  detrás de un backend propio; nunca en la app ni en `.env` (se compila en el APK).
- Las tasas son referenciales (publicación diaria del BCE); no sirven para operar.

## Impacto a largo plazo

Cambiar de proveedor es cambiar `fx_config.baseUrl` en la consola (alterno documentado:
`open.er-api.com`, que requeriría su propio modelo). El patrón datasource + caché + `isStale`
es la plantilla para integrar futuros servicios de terceros.
