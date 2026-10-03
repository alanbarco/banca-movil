# Data Model: MVP Banca Móvil Digital Personalizada

**Feature**: `001-digital-banking-mvp` | **Date**: 2026-10-03

Fuentes de datos: Cloud Firestore (datos del cliente), Remote Config (contenido y flags,
ver [contracts/remote-config.md](./contracts/remote-config.md)) y API externa de divisas
(ver [contracts/fx-external-api.md](./contracts/fx-external-api.md)).

Convenciones: montos en **centavos (`int`)**, moneda `USD`; fechas como `Timestamp` en
Firestore y `DateTime` (UTC) en dominio.

## Firestore

```text
users/{uid}                                   ← Cliente
├── accounts/{accountId}                      ← Cuenta
│   └── movements/{movementId}                ← Movimiento
└── devices/{fcmToken}                        ← Dispositivo para push
```

### Cliente — `users/{uid}`

| Campo | Tipo | Reglas |
|---|---|---|
| `fullName` | string | 3–80 caracteres |
| `email` | string | igual a `request.auth.token.email`; inmutable |
| `segment` | string | `student` \| `professional` \| `entrepreneur` |
| `interests` | string[] | 1–5 valores del catálogo (`savings`, `investment`, `travel`, `education`, `business`) |
| `preferences.notificationsEnabled` | bool | default `false` hasta que el cliente decide |
| `termsVersion` | string | versión aceptada (de Remote Config) |
| `termsAcceptedAt` | timestamp | inmutable |
| `createdAt` | timestamp | `request.time`; inmutable |
| `updatedAt` | timestamp | `request.time` en cada update |

- Cliente puede **crear** su documento una vez (en el batch de onboarding) y **actualizar**
  solo `segment`, `interests`, `preferences`, `updatedAt`.
- `hideBalances` se guarda **localmente** (preferencia de dispositivo), no en Firestore.

### Cuenta — `users/{uid}/accounts/{accountId}`

| Campo | Tipo | Reglas |
|---|---|---|
| `type` | string | `savings` \| `checking` |
| `number` | string | 10 dígitos; en UI solo últimos 4 (`•••• 1234`) |
| `currency` | string | `USD` |
| `balanceCents` | int | ≥ 0; en creación ≤ 1 000 000 (US$ 10 000) |
| `openedAt` | timestamp | |
| `updatedAt` | timestamp | |

- Creación solo dentro del batch de onboarding (ver [contracts/firestore-security.md](./contracts/firestore-security.md)).
- Después: solo lectura para el cliente; el banco la modifica con privilegios de admin.

### Movimiento — `users/{uid}/accounts/{accountId}/movements/{movementId}`

| Campo | Tipo | Reglas |
|---|---|---|
| `date` | timestamp | orden descendente en consultas |
| `description` | string | 1–60 caracteres |
| `amountCents` | int | > 0; en creación ≤ 500 000 |
| `type` | string | `credit` (ingreso) \| `debit` (egreso) |
| `balanceAfterCents` | int | saldo resultante |

- Consulta: `orderBy('date', descending) .limit(20)` en tiempo real + paginación con
  `startAfterDocument` (FR-011). No requiere índice compuesto.
- Invariante: el `balanceAfterCents` del movimiento más reciente = `balanceCents` de la cuenta
  (el script admin lo garantiza con transacción).

### Dispositivo — `users/{uid}/devices/{fcmToken}`

| Campo | Tipo |
|---|---|
| `platform` | string (`android`/`ios`) |
| `createdAt` / `lastSeenAt` | timestamp |

- El cliente crea/borra sus propios documentos. Al cerrar sesión se borra el del dispositivo.

## Entidades de dominio (Dart puro)

| Entidad | Origen | Notas |
|---|---|---|
| `UserProfile` | `users/{uid}` | expuesta a otras features vía contrato `CurrentUserProfile` en `core` |
| `Account` | accounts | `maskedNumber` derivado |
| `Movement` | movements | `isCredit` derivado |
| `DataSnapshot<T>` | wrapper | `data`, `isStale` (de caché), `lastSyncedAt` → estado "desactualizado" (FR-028) |
| `HomeLayout` / `HomeSection` | Remote Config | `type`, `order`, `interests`, `payload` (map), `action` |
| `FeatureFlag` | Remote Config | `key`, `enabled`, `segments` |
| `OnboardingSeed` | Remote Config | saldo inicial + plantillas de movimientos |
| `ExchangeRates` | API externa | `base`, `date`, `rates: Map<String,double>`, `fetchedAt`, `isStale` |
| `PushMessage` | FCM | `title`, `body`, `route` |
| `Failure` | core | `network`, `timeout`, `unauthorized`, `notFound`, `validation(field)`, `server`, `unknown` |

## Estados (state machines principales)

### Sesión (`AuthBloc`)

```text
unknown ──(auth stream)──► unauthenticated ──login/register ok──► authenticated
authenticated ──logout / inactividad 5 min / token revocado──► unauthenticated
```

### Onboarding (`OnboardingCubit`) — pasos

```text
credentials → profile(segment) → interests → terms → submitting → done
                                                        └─ error (conserva datos, reintentar)
```
Cada paso emite `onboarding_step_viewed`; salir antes de `done` emite `onboarding_abandoned`.

### Carga de datos (todas las pantallas, FR-027)

```text
initial → loading → success(data, isStale=false)
                  → stale(data, lastSyncedAt)     (offline / caché)
                  → empty
                  → failure(Failure)  ──retry──► loading
```

## Validaciones (de la spec)

| Regla | Requisito |
|---|---|
| Contraseña ≥ 8, con letras y números | FR-002 |
| Términos aceptados para avanzar | Escenario US1-2 |
| Segmento obligatorio + ≥ 1 interés | FR-003 |
| Correo ya registrado → error en campo, sin perder datos | US1-3, FR-031 |
| Montos mostrados enmascarados si `hideBalances` | FR-010 |
