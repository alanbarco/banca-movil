# Contract: Remote Config

Plantilla versionada en `firebase/remoteconfig.template.json`, desplegada con
`firebase deploy --only remoteconfig`. Los mismos parámetros existen como defaults locales en
`assets/config/remote_config_defaults.json` (fallback seguro, FR-017).

Todos los parámetros JSON incluyen `schemaVersion`. Si la app recibe una versión mayor que la
soportada o JSON inválido, usa el último valor válido y registra el incidente.

## `home_layout` (JSON)

```json
{
  "schemaVersion": 1,
  "segments": {
    "default":      { "sections": [ /* HomeSection */ ] },
    "student":      { "sections": [ ] },
    "professional": { "sections": [ ] },
    "entrepreneur": { "sections": [ ] }
  }
}
```

**HomeSection**

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `id` | string | sí | único dentro del layout |
| `type` | string | sí | `accounts_summary` \| `banner` \| `offer_carousel` \| `quick_actions` \| `tip` |
| `order` | int | sí | orden ascendente |
| `interests` | string[] | no | si existe, la sección se prioriza (y en `offer`/`tip`, se filtra) por intereses |
| `flag` | string | no | clave de `feature_flags`; si está apagada, la sección no se muestra |
| `payload` | object | según tipo | ver abajo |

Payloads por tipo:

- `accounts_summary`: `{}` (la registra la feature `accounts`).
- `banner`: `{ "title", "subtitle", "imageUrl?", "color?", "route?" }`
- `offer_carousel`: `{ "items": [ { "id", "title", "description", "interests?", "route?" } ] }`
- `quick_actions`: `{ "items": [ { "id", "label", "icon", "route", "flag?" } ] }`
- `tip`: `{ "title", "body" }`

Resolución: layout del segmento del cliente → si no existe, `default` → si el parámetro es
inválido, defaults locales. Sección con `type` desconocido o payload inválido → se omite
(FR-016).

## `feature_flags` (JSON)

```json
{
  "schemaVersion": 1,
  "flags": {
    "fx_service":          { "enabled": true,  "segments": [] },
    "offers":              { "enabled": true,  "segments": ["student", "professional", "entrepreneur"] },
    "push_opt_in_prompt":  { "enabled": true,  "segments": [] },
    "demo_fault_panel":    { "enabled": false, "segments": [] }
  }
}
```

`segments` vacío = todos los segmentos. Flag ausente = valor por defecto local.

## `onboarding_seed` (JSON)

```json
{
  "schemaVersion": 1,
  "account": { "type": "savings", "initialBalanceCents": 125000 },
  "movements": [
    { "description": "Depósito de apertura", "amountCents": 100000, "type": "credit", "daysAgo": 10 },
    { "description": "Transferencia recibida", "amountCents": 40000, "type": "credit", "daysAgo": 6 },
    { "description": "Supermercado", "amountCents": 15000, "type": "debit", "daysAgo": 3 }
  ]
}
```

La app calcula `balanceAfterCents` de cada movimiento de modo que el último coincida con el
saldo inicial. Límites aplicados por Security Rules (ver firestore-security.md).

## `fx_config` (JSON)

```json
{ "schemaVersion": 1, "baseUrl": "https://api.frankfurter.dev/v1", "base": "USD",
  "symbols": ["EUR", "MXN", "BRL", "GBP", "JPY", "CAD", "CNY"], "timeoutMs": 8000 }
```

## `terms` (JSON)

```json
{ "schemaVersion": 1, "version": "2026-10", "url": "https://<pages-del-repo>/terms.html" }
```

## Actualización

- Al iniciar: `fetchAndActivate()` (intervalo mínimo 5 min en release, 0 en debug).
- En ejecución: listener `onConfigUpdated` → `activate()` → los Cubits de inicio/flags
  re-emiten estado (SC-005).
