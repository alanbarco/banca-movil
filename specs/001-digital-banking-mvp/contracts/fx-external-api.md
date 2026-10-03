# Contract: Servicio externo de tipos de cambio

Proveedor: **Frankfurter** (público, gratuito, sin API key). URL base configurable en Remote
Config `fx_config.baseUrl`. Proveedor alterno documentado: `https://open.er-api.com/v6`.

## Request

```http
GET {baseUrl}/latest?base=USD&symbols=EUR,MXN,BRL,GBP,JPY,CAD,CNY
Accept: application/json
```

Nota: Frankfurter publica las divisas del BCE (no incluye COP ni PEN). Verificar al
implementar los nombres de query params vigentes (`base`/`symbols`, legado `from`/`to`).

## Response 200 (campos consumidos)

```json
{ "base": "USD", "date": "2026-10-02", "rates": { "EUR": 0.92, "MXN": 18.4 } }
```

| Campo | Uso |
|---|---|
| `base` | divisa base (debe ser `USD`; si no, se trata como respuesta inválida) |
| `date` | fecha de las tasas mostrada al cliente (FR-019) |
| `rates` | mapa divisa → tasa; divisas ausentes se omiten |

## Conversión (cliente)

- USD → X: `monto × rates[X]`
- X → USD: `monto ÷ rates[X]`
- X → Y: `monto ÷ rates[X] × rates[Y]`
- Se muestra la tasa efectiva usada (FR-020), redondeo a 2 decimales (JPY: 0).

## Política de resiliencia

| Aspecto | Valor |
|---|---|
| Timeout | `fx_config.timeoutMs` (default 8000 ms) |
| Reintentos | 3, solo GET, backoff 0.5 s → 1 s → 2 s, en timeout/5xx/error de conexión |
| No reintenta | 4xx |
| Caché | última respuesta válida + `fetchedAt` en `shared_preferences` |
| Sin servicio + caché | muestra caché marcada desactualizada + reintentar (FR-021) |
| Sin servicio sin caché | mensaje claro + reintentar; resto de la app operativa (FR-022) |
| Observabilidad | `fx_service_failure` con `reason` (timeout/http_5xx/network/invalid) |
