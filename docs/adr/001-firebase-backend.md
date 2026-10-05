# ADR-001: Firebase (plan Spark) como backend

- **Estado**: aceptada · 2026-10-03
- **Fuente**: [research.md R1](../../specs/001-digital-banking-mvp/research.md)

## Problema

El MVP necesita autenticación, datos de cuentas en tiempo real, configuración remota,
notificaciones push y observabilidad, con **interacción real** (los requerimientos descartan
soluciones solo con datos simulados), **costo cero** y una ventana de 2 días.

## Alternativas evaluadas

| Opción | A favor | En contra |
|---|---|---|
| **Firebase** (Auth, Firestore, Remote Config, FCM, Crashlytics, Analytics) | Un proveedor, SDKs oficiales de Flutter, tiempo real y persistencia offline incluidos, consola que sirve de "backoffice" | Modelo documental (no relacional); sin Cloud Functions en plan gratuito |
| Supabase | Postgres y RLS, más natural para un banco | Seguiría haciendo falta FCM (dos proveedores); Docker para desarrollo local |
| Backend propio (Dart Shelf / Node) | Control total | Construir auth, persistencia, tiempo real y despliegue: inviable en 2 días |

## Decisión

Firebase en plan **Spark**: Authentication (correo/contraseña), Cloud Firestore con
persistencia offline, Remote Config (con actualizaciones en tiempo real), Cloud Messaging,
Crashlytics y Analytics. La configuración vive como código en `firebase/` (reglas, índices y
plantilla de Remote Config) y se despliega con la CLI.

## Trade-offs

- **Sin Cloud Functions** (requiere plan Blaze): el aprovisionamiento de la cuenta lo hace el
  cliente en un batch validado por reglas ([ADR-002](002-onboarding-provisioning-batch.md)) y
  los avisos de movimiento los envía un script local (`tools/admin`).
- **Sin Cloud Storage** (buckets nuevos requieren Blaze): los banners usan colores e íconos del
  design system o URLs públicas.
- **Modelo documental**: los montos se guardan en centavos (`int`) y las cuentas cuelgan de
  `users/{uid}` para que las reglas sean simples ("solo tu árbol").
- **Lock-in**: el acceso a Firebase está detrás de interfaces de `domain`
  (`AccountsRepository`, `AuthRepository`, `FxRepository`…); cambiar de backend afecta solo
  a la capa `data`.

## Impacto a largo plazo

En producción, el core bancario sería la fuente de verdad y Firestore quedaría como capa de
lectura en tiempo real (un patrón tipo CQRS). El aprovisionamiento y los avisos pasarían a
servidor (Cloud Functions en Blaze o backend propio) sin tocar `presentation`. Las cuotas de
Spark (50 000 lecturas/día) bastan para la demo, no para producción.
