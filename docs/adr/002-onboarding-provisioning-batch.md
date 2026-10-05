# ADR-002: Aprovisionamiento de la cuenta en un batch validado por reglas

- **Estado**: aceptada · 2026-10-03
- **Fuente**: [research.md R2](../../specs/001-digital-banking-mvp/research.md) ·
  [firestore-security.md](../../specs/001-digital-banking-mvp/contracts/firestore-security.md)

## Problema

Un cliente nuevo debe ver de inmediato una cuenta de ahorros con saldo y movimientos
(FR-004, SC-001). Sin servidor (ver [ADR-001](001-firebase-backend.md)), alguien tiene que
crear esos datos, y el cliente **no** debe poder fabricarse saldo después.

## Alternativas evaluadas

| Opción | En contra |
|---|---|
| Cloud Function `onCreate` | La solución de producción, pero requiere plan Blaze |
| Un operador crea la cuenta a mano | El cliente no puede usar la app de inmediato (rompe SC-001) |
| El cliente escribe libremente sus cuentas | Inseguro: podría crearse saldo en cualquier momento |
| **Batch atómico validado por reglas** | — |

## Decisión

El cliente crea, en **un único `WriteBatch`**, su perfil `users/{uid}`, una cuenta y los
movimientos semilla. Las reglas de Firestore solo permiten crear cuentas y movimientos si el
perfil **no existía antes** del batch y **existirá después** (`!exists` + `existsAfter`), con
montos acotados y campos validados. Después del onboarding, cuentas y movimientos son de
**solo lectura** para el cliente. La plantilla de la semilla viene de Remote Config
(`onboarding_seed`), no está embebida en la app.

## Trade-offs

- Un cliente malicioso podría alterar los montos de **su propia** semilla, dentro de los
  límites de las reglas (saldo ≤ $10 000, movimientos ≤ $5 000). Riesgo aceptado para un MVP;
  mitigado por los límites.
- Cada documento del batch usa 2 accesos de reglas (`exists` + `existsAfter`); con el límite
  de 20 por batch, la semilla admite hasta 8 movimientos.
- Si el batch falla, no queda nada a medias (atomicidad), y la app ofrece completar el
  registro en el siguiente inicio de sesión.

## Impacto a largo plazo

En producción el aprovisionamiento lo hace el core bancario en servidor y las reglas pasan a
negar toda escritura de cuentas y movimientos desde el cliente. La app no cambia: el
onboarding solo deja de escribir la semilla.
