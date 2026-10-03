# Contract: Firestore Security Rules

Archivo versionado `firebase/firestore.rules`, desplegado con
`firebase deploy --only firestore:rules`. Las reglas **nunca** quedan en modo test/abierto.
Las herramientas admin (`tools/admin`, consola) usan privilegios de admin y no pasan por
estas reglas.

## Matriz de acceso (cliente autenticado con `uid`)

| Ruta | read | create | update | delete |
|---|---|---|---|---|
| `users/{uid}` (propio) | ✅ | ✅ una vez, campos válidos, `createdAt == request.time` | ✅ solo `segment`, `interests`, `preferences`, `updatedAt` | ❌ |
| `users/{uid}/accounts/{id}` | ✅ | ✅ **solo en batch de onboarding** | ❌ | ❌ |
| `.../accounts/{id}/movements/{id}` | ✅ | ✅ **solo en batch de onboarding** | ❌ | ❌ |
| `users/{uid}/devices/{token}` | ✅ | ✅ | ✅ | ✅ |
| Cualquier ruta de otro `uid` | ❌ | ❌ | ❌ | ❌ |
| Usuario no autenticado | ❌ | ❌ | ❌ | ❌ |

## Condición "batch de onboarding"

Una cuenta o movimiento solo se puede crear si, evaluado en la misma escritura atómica:

1. `!exists(/users/{uid})` — el perfil **no existía** antes del batch, y
2. `existsAfter(/users/{uid})` — el perfil **existirá** al confirmarse el batch, y
3. montos dentro de límites: cuenta `0 ≤ balanceCents ≤ 1_000_000`; movimiento
   `0 < amountCents ≤ 500_000`; `currency == 'USD'`; `type` en el catálogo.

Efecto: un cliente ya registrado no puede crear cuentas ni movimientos nuevos.

## Casos de prueba de reglas (validación manual o con emulador)

| # | Acción | Esperado |
|---|---|---|
| 1 | Usuario A lee `users/B/accounts` | denegado |
| 2 | Usuario A (ya registrado) crea `users/A/accounts/x` | denegado |
| 3 | Usuario nuevo envía batch perfil + cuenta + 3 movimientos válidos | permitido |
| 4 | Usuario nuevo envía batch con `balanceCents = 99_999_999` | denegado |
| 5 | Usuario A actualiza `users/A.email` | denegado |
| 6 | Usuario A actualiza `users/A.interests` | permitido |
| 7 | No autenticado lee cualquier documento | denegado |
