# Research: MVP Banca Móvil Digital Personalizada

**Feature**: `001-digital-banking-mvp` | **Date**: 2026-10-03 | **Plan**: [plan.md](./plan.md)

Cada decisión sigue el formato Decision / Rationale / Alternatives. Las marcadas con **→ ADR**
se convierten en un ADR en `docs/adr/` durante la implementación (Principio VIII).

---

## R1. Backend: Firebase (plan Spark) → ADR-001

- **Decision**: Firebase Authentication + Cloud Firestore + Remote Config + Cloud Messaging +
  Crashlytics + Analytics, todo en plan Spark (sin tarjeta).
- **Rationale**: Un solo proveedor y una sola configuración (`flutterfire configure`), SDKs
  oficiales para Flutter, datos reales en tiempo real (listeners), persistencia offline
  incluida, push gratuito y consola de administración que sirve como "backoffice" del banco.
  Encaja con la ventana de 2 días.
- **Alternatives considered**:
  - *Supabase*: modelo relacional más natural para un banco y RLS potente, pero más
    configuración inicial, Docker para local y dos proveedores (seguiría haciendo falta FCM).
  - *Backend propio (Dart Shelf / Node)*: control total, pero hay que construir auth,
    persistencia, tiempo real y despliegue; inviable en 2 días.
  - *Firebase Local Emulator Suite como entorno principal*: gratis, pero requiere Java y no
    sirve para la demo en dispositivo físico; se descarta para el MVP.
- **Restricciones de Spark descubiertas**:
  - **Cloud Functions** requiere Blaze → prohibido (constitución VII).
  - **Cloud Storage**: los buckets nuevos requieren Blaze desde 2024 → no se usa. Las
    imágenes de banners se sirven por URL pública gratuita (GitHub Pages/raw del repo) o se
    usan íconos + colores del design system.

## R2. Aprovisionamiento de cuenta y movimientos al registrarse (sin Cloud Functions) → ADR-002

- **Decision**: El cliente crea, en **un único `WriteBatch` atómico**, su perfil
  `users/{uid}`, su cuenta de ahorros y los movimientos semilla. Las Security Rules solo
  permiten crear cuentas/movimientos si el perfil **no existía antes** del batch
  (`!exists(...)`) y **existirá después** (`existsAfter(...)`), con montos acotados. Después
  del onboarding, cuentas y movimientos son de **solo lectura** para el cliente.
- **Rationale**: Cumple FR-004 sin servidor ni costo y sin abrir la puerta a que un cliente
  se fabrique saldo más tarde. La plantilla de la semilla (saldo inicial, movimientos) viene de
  Remote Config (`onboarding_seed`), no está embebida en la app.
- **Alternatives considered**:
  - *Cloud Function `onCreate`*: la solución "correcta" de producción, pero requiere Blaze.
  - *Operador crea la cuenta manualmente*: rompe SC-001 (cliente usa la app de inmediato).
  - *Cliente escribe libremente sus cuentas*: inseguro, viola el Principio VI.
- **Trade-off / riesgo documentado**: Un cliente malicioso podría alterar los montos de su
  propia semilla dentro de los límites de las reglas. Mitigación: límites en reglas; en
  producción el aprovisionamiento lo haría el core bancario en servidor.

## R3. Modelo de datos en Firestore

- **Decision**: Subcolecciones bajo el usuario: `users/{uid}`,
  `users/{uid}/accounts/{accountId}`, `users/{uid}/accounts/{accountId}/movements/{id}`,
  `users/{uid}/devices/{token}`. Montos en **centavos (`int`)**.
- **Rationale**: El `uid` en la ruta simplifica y endurece las reglas ("solo tu árbol"),
  evita índices compuestos y permite listeners por cuenta. Centavos evitan errores de coma
  flotante con dinero.
- **Alternatives considered**: Colecciones raíz con `ownerId` (requiere índices y reglas por
  campo); `double` para montos (errores de redondeo).

## R4. Personalización y Server-Driven UI → ADR-003

- **Decision**: Remote Config con parámetros JSON: `home_layout` (layouts por segmento con
  secciones tipadas y tags de interés), `feature_flags` (habilitado + segmentos), y
  `onboarding_seed`. La app elige el layout según el segmento del perfil y ordena/filtra por
  intereses. Se usa **Remote Config real-time** (`onConfigUpdated`) además de
  `fetchAndActivate` al iniciar. Los valores por defecto se cargan desde un asset JSON
  (`setDefaults`).
- **Rationale**: Gratis, con caché persistente en dispositivo (funciona offline), consola
  amigable para "el banco" y propagación en segundos (SC-005). La evaluación por segmento en
  el cliente evita depender de las condiciones de Remote Config basadas en propiedades de
  Analytics, que tardan en propagarse.
- **Alternatives considered**:
  - *Layouts en Firestore*: también válido y en tiempo real, pero mezcla contenido con datos
    transaccionales y requiere más reglas.
  - *Condiciones de Remote Config por user property*: menos JSON, pero latencia de
    propagación impredecible para la demo.
- **Registro de componentes**: `core/sdui` define `SectionRegistry` (tipo → builder). Cada
  feature registra sus tipos (p. ej. `accounts_summary` lo registra `accounts`), así el inicio
  compone secciones de varias features **sin imports cruzados** (Principio I). Tipos
  desconocidos o JSON inválido → se omiten y se reporta `sdui_section_skipped`.

## R5. Servicio externo: tipos de cambio → ADR-004

- **Decision**: API pública **Frankfurter** (gratuita, sin API key, tasas BCE) vía `dio`,
  con base USD. La URL base se lee de Remote Config (`fx_config.baseUrl`) para poder cambiar
  de proveedor sin publicar la app; proveedor alterno documentado: `open.er-api.com`.
- **Rationale**: Relevante para el ecosistema financiero, sin costo ni registro, demuestra
  integración HTTP real con timeout, reintentos y caché.
- **Alternatives considered**: Micro-app web en WebView (más "micro-frontend", pero más
  tiempo y peor testabilidad); APIs con key gratuita (fricción de registro y secretos).
- **Resiliencia**: timeout 8 s; hasta 3 reintentos con backoff exponencial (0.5 s, 1 s, 2 s)
  solo en GET; última respuesta válida guardada en `shared_preferences` con timestamp.

## R6. Resiliencia, offline y simulación de fallos → ADR-005

- **Decision**:
  - Cuentas/movimientos: persistencia offline nativa de Firestore; `snapshot.metadata.isFromCache`
    determina el estado "datos desactualizados"; la hora de la última sincronización real se
    guarda localmente.
  - Conectividad: `connectivity_plus` → `ConnectivityCubit` global → banner offline.
  - **Simulador de fallos** (`core/fault_injection`): panel de demo (solo con
    `--dart-define=DEMO_TOOLS=true`) con modos por servicio: normal / sin conexión / latencia
    (ms) / error. Implementación: decoradores de repositorio + interceptor `dio`; el modo
    "sin conexión" de Firestore usa `disableNetwork()`/`enableNetwork()` reales.
- **Rationale**: Demuestra FR-027–FR-032 con comportamiento real (no solo UI simulada) y sin
  tocar la lógica de negocio.
- **Alternatives considered**: Modo avión manual (no permite aislar un servicio); proxy de red
  (complejo de montar).

## R7. Notificaciones push

- **Decision**: FCM con **topics** `all` y `segment_<segmento>` para envíos masivos/por
  segmento, y tokens por dispositivo en `users/{uid}/devices` para envíos personales.
  Payload con `data.route` para deep link vía `go_router`. Primer plano: aviso in-app
  (tarjeta flotante arriba en un `Overlay`, se cierra sola a los 7 s), sin dependencia extra. Al cerrar sesión: unsubscribe de topics y
  `deleteToken()`.
- **Envío**: consola de Firebase (Messaging) para campañas por topic, y script local
  `tools/admin` (Node + `firebase-admin`, gratis) que registra un movimiento, actualiza el
  saldo de forma atómica y notifica al cliente.
- **Alternatives considered**: Cloud Functions trigger (Blaze); `flutter_local_notifications`
  para foreground (dependencia extra innecesaria para el MVP).

## R8. Sesión e inactividad

- **Decision**: Firebase Auth persiste la sesión (FR-005). `SessionTimeoutService` en `core`
  reinicia un temporizador de 5 min con cada interacción (`Listener` en la raíz) y con el
  ciclo de vida; al vencer, cierra sesión y redirige al login conservando el correo.
- **Datos locales al cerrar sesión (FR-008)**: se cancelan listeners, se limpian cachés
  propias y se marca `pendingCacheClear`; en el siguiente arranque se ejecuta
  `clearPersistence()` de Firestore antes de cualquier lectura (no se puede limpiar con la
  instancia en uso).
- **`flutter_secure_storage`**: no se requiere en el MVP porque no se persiste ningún dato
  sensible propio (los tokens los gestiona el SDK). Se incorporará si aparece uno.

## R9. Arquitectura de app y librerías

- **Decision**: App Flutter única en la raíz del repo, `lib/{app,core,features}`;
  `flutter_bloc` + `equatable` + sealed classes (sin codegen); `go_router` con `redirect`
  según `AuthBloc`; `get_it` con registro manual por feature; `Result<T>` y `Failure` propios
  en `core/error`; `intl` para moneda (`es_EC`, USD).
- **Rationale**: Sin `build_runner`/`freezed` se elimina tiempo de generación y complejidad;
  suficiente para el tamaño del MVP. → **ADR-006** documenta además la evolución a paquetes
  por feature (pub workspaces) como estrategia de escalamiento a equipos independientes.
- **Alternatives considered**: `injectable` + `freezed` (codegen, más ceremonia); `fpdart`
  para `Either` (dependencia extra para un tipo de 20 líneas); monorepo multi-paquete
  (descartado en constitución v2.0.0).

## R10. Pruebas y CI

- **Decision**:
  - Unit: `test`, `bloc_test`, `mocktail` (casos de uso, repositorios, BLoCs/Cubits).
  - Data sources Firestore: `fake_cloud_firestore`.
  - Widget: `flutter_test` con repositorios mockeados (estados carga/éxito/error/offline).
  - E2E: `integration_test` contra el proyecto Firebase real de desarrollo: registra un
    usuario único → ve cuenta y saldo → abre movimientos (SC-012).
  - CI (GitHub Actions): format → analyze → test con cobertura (umbral 70 % en `domain` y
    `presentation/bloc`) → `flutter build apk --debug`.
- **Alternatives considered**: Patrol (mejor para permisos nativos, pero setup extra); E2E con
  fakes (no demuestra integración real).
- **Riesgo**: el E2E deja usuarios de prueba en el proyecto de desarrollo; se documenta y se
  usan correos `e2e+<timestamp>@...` identificables.

## R11. Observabilidad

- **Decision**: `ObservabilityService` en `core` (interfaz) con implementación Firebase:
  Crashlytics (`FlutterError.onError`, `PlatformDispatcher.instance.onError`, errores no
  fatales) y Analytics (eventos del catálogo en [contracts/analytics-events.md](./contracts/analytics-events.md)).
  Logger estructurado propio con redacción de PII.
- **Rationale**: Gratis, cubre crashes y funnels (abandono de onboarding) y queda desacoplado
  del proveedor.
- **Alternatives considered**: Sentry free tier (segundo proveedor); Performance Monitoring
  (útil pero fuera del alcance de 2 días; documentado como evolución).
