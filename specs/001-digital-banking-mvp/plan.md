# Implementation Plan: MVP Banca Móvil Digital Personalizada

**Branch**: `001-digital-banking-mvp` | **Date**: 2026-10-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-digital-banking-mvp/spec.md`

## Summary

App Flutter única (Android) de banca 100 % digital con onboarding y autenticación, cuentas y
movimientos en tiempo real, inicio personalizado por segmento mediante Server-Driven UI y
feature flags, un servicio externo de tipos de cambio y notificaciones push, todo resiliente
a conectividad degradada. Enfoque técnico: Clean Architecture feature-first con BLoC/Cubit;
Firebase plan Spark como backend real (Auth, Firestore con persistencia offline, Remote Config
real-time, FCM, Crashlytics, Analytics); API pública Frankfurter vía `dio`; aprovisionamiento
de cuenta en un batch atómico protegido por Security Rules (sin Cloud Functions); simulador de
fallos para demostrar escenarios degradados. Ver [research.md](./research.md).

## Technical Context

**Language/Version**: Dart ≥ 3.6 / Flutter estable (≥ 3.27)

**Primary Dependencies**: `flutter_bloc`, `bloc`, `equatable`, `go_router`, `get_it`,
`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_remote_config`,
`firebase_messaging`, `firebase_crashlytics`, `firebase_analytics`, `dio`,
`shared_preferences`, `connectivity_plus`, `intl`

**Storage**: Cloud Firestore (remoto + persistencia offline), Remote Config (caché en
dispositivo), `shared_preferences` (preferencias y caché de divisas)

**Testing**: `flutter_test`, `bloc_test`, `mocktail`, `fake_cloud_firestore`,
`integration_test`; lints `flutter_lints`

**Target Platform**: Android 8.0+ (API 26+; emulador API 33+ para la demo); iOS compatible no
requerido

**Project Type**: mobile-app (+ configuración de Firebase como código + scripts admin Node)

**Performance Goals**: abrir app → saldos < 5 s (SC-002); saldos desde caché offline < 2 s
(SC-003); movimiento nuevo visible < 10 s (SC-004); 60 fps en listas de movimientos

**Constraints**: costo cero (Spark, sin Cloud Functions ni Cloud Storage); offline-capable;
sin PII en logs; ventana de desarrollo de 2 días

**Scale/Scope**: demo con decenas de clientes; ~10 pantallas; 5 features
(`auth`, `accounts`, `personalization`, `fx`, `notifications`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Cumplimiento en el diseño | Estado |
|---|---|---|
| I. Clean Architecture Feature-First | `lib/{app,core,features}`; capas `domain/data/presentation` por feature; `domain` Dart puro; sin imports entre features: el inicio compone secciones de otras features vía `SectionRegistry` (core) y el perfil del cliente se expone vía contrato `CurrentUserProfile` (core); `Result`/`Failure` propios; ADR-006 traza la evolución a paquetes | ✅ |
| II. BLoC/Cubit (NON-NEGOTIABLE) | `AuthBloc`, `OnboardingCubit`, `AccountsCubit`, `MovementsBloc`, `HomeLayoutCubit`, `FeatureFlagsCubit`, `FxCubit`, `ConnectivityCubit`, `NotificationsCubit`; dependen solo de casos de uso; estados sealed + `Equatable`; `bloc_test` por cada uno | ✅ |
| III. Flags + SDUI | `FeatureFlagService` y `SectionRegistry` en core; defaults locales desde asset; reglas por segmento/intereses en JSON remoto; secciones desconocidas se omiten y se reportan ([remote-config.md](./contracts/remote-config.md)) | ✅ |
| IV. Resiliencia offline-first | Persistencia offline Firestore + `isFromCache`/`lastSyncedAt`; FX con timeout, 3 reintentos GET con backoff y caché; `ConnectivityCubit` + banner; estados explícitos por pantalla; simulador de fallos (decoradores + interceptor + `disableNetwork`) | ✅ |
| V. Calidad por pruebas | Unit (casos de uso, repos, BLoCs), widget (carga/éxito/error/offline), E2E `integration_test` registro→cuentas→movimientos; CI con umbral 70 % | ✅ |
| VI. Seguridad y observabilidad | Sesión Firebase Auth; Security Rules con matriz y batch de onboarding ([firestore-security.md](./contracts/firestore-security.md)); config cliente versionada, service account ignorada; saldos ocultables; `ObservabilityService` + catálogo sin PII ([analytics-events.md](./contracts/analytics-events.md)); `Semantics`, escalado de texto, 48 dp. `flutter_secure_storage` no se incluye porque no se persiste dato sensible propio (R8) | ✅ |
| VII. Costo cero + integración real | Solo Spark + API pública sin key + GitHub Actions; sin Functions/Storage; rules, índices y Remote Config versionados y desplegables con Firebase CLI; semilla desde Remote Config | ✅ |
| VIII. Decisiones documentadas + IA | ADR-001…006 derivados de research; diagramas Mermaid en `docs/architecture.md`; `docs/operations.md`; `docs/ai-usage.md`; README reproducible ([quickstart.md](./quickstart.md)) | ✅ |
| Flujo / Quality gates | TBD sobre `main`, Conventional Commits, CI: format → analyze → test+cobertura → build APK debug | ✅ |

**Resultado (pre y post diseño)**: PASS, sin violaciones. Complexity Tracking vacío.

## Project Structure

### Documentation (this feature)

```text
specs/001-digital-banking-mvp/
├── plan.md              # Este archivo
├── research.md          # Fase 0: decisiones R1–R11
├── data-model.md        # Fase 1: Firestore, entidades, estados
├── quickstart.md        # Fase 1: setup + escenarios de validación V1–V20
├── contracts/           # Fase 1
│   ├── remote-config.md
│   ├── firestore-security.md
│   ├── fx-external-api.md
│   ├── push-notifications.md
│   ├── ui-routes.md
│   └── analytics-events.md
├── checklists/requirements.md
└── tasks.md             # Fase 2 (/speckit-tasks)
```

### Source Code (repository root)

La app Flutter vive en la **raíz del repositorio** (junto a `.specify/`, `specs/`, `docs/`):
con una sola app no se justifica `apps/`.

```text
.
├── lib/
│   ├── main.dart                      # bootstrap: Firebase, Crashlytics, DI, runApp
│   ├── firebase_options.dart          # generado por flutterfire (versionado)
│   ├── app/
│   │   ├── app.dart                   # MaterialApp.router, tema, BlocProviders globales
│   │   ├── di.dart                    # get_it: registra core + cada feature
│   │   ├── router.dart                # GoRouter: compone rutas de features + redirect
│   │   └── shell/                     # scaffold con navegación inferior, banner offline
│   ├── core/
│   │   ├── error/                     # Result<T>, Failure
│   │   ├── network/                   # dio factory, retry + fault interceptors
│   │   ├── connectivity/              # ConnectivityCubit
│   │   ├── storage/                   # wrapper shared_preferences
│   │   ├── flags/                     # FeatureFlagService (+ impl Remote Config)
│   │   ├── sdui/                      # HomeSection, SectionRegistry, parser
│   │   ├── session/                   # CurrentUserProfile (contrato), SessionTimeoutService
│   │   ├── observability/             # ObservabilityService, logger con redacción
│   │   ├── fault_injection/           # FaultInjector, decoradores, panel debug
│   │   ├── routing/                   # AppRoutes (constantes)
│   │   └── ui/                        # design system: tema, colores, skeleton, estados, MoneyText
│   └── features/
│       ├── auth/                      # login, registro/onboarding, recuperar, perfil
│       │   ├── domain/  data/  presentation/
│       ├── accounts/                  # resumen, detalle, movimientos; registra 'accounts_summary'
│       │   ├── domain/  data/  presentation/
│       ├── personalization/           # inicio SDUI, banners, ofertas, quick actions, tips
│       │   ├── domain/  data/  presentation/
│       ├── fx/                        # tipos de cambio y conversor (servicio externo)
│       │   ├── domain/  data/  presentation/
│       └── notifications/             # permisos, tokens/topics, deep links, aviso in-app
│           ├── domain/  data/  presentation/
├── assets/config/remote_config_defaults.json
├── test/                              # espejo de lib/: unit + widget
│   ├── core/  features/<feature>/{domain,data,presentation}/
├── integration_test/
│   └── critical_flow_test.dart        # registro → cuentas → movimientos
├── firebase/
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   └── remoteconfig.template.json
├── firebase.json  .firebaserc
├── tools/admin/                       # Node + firebase-admin: add-movement, send-push
├── docs/
│   ├── adr/                           # ADR-001…006
│   ├── architecture.md                # diagramas Mermaid (componentes, flujos, dependencias)
│   ├── operations.md                  # despliegue, monitoreo, escenarios degradados
│   └── ai-usage.md
├── .github/workflows/ci.yml
├── android/  ios/
├── pubspec.yaml  analysis_options.yaml
└── README.md
```

**Structure Decision**: App Flutter única en la raíz, `lib/{app,core,features}` según el
Principio I. La configuración de Firebase vive como código en `firebase/` y las herramientas
del banco en `tools/admin`. Las features se comunican solo mediante contratos de `core`
(`SectionRegistry`, `CurrentUserProfile`, `AppRoutes`, `FeatureFlagService`).

### Orden de implementación sugerido (para `/speckit-tasks`)

1. **Setup**: `flutter create`, Firebase, lints, DI, router, tema, `core/error`, CI.
2. **Fundacional**: observabilidad, conectividad, flags + defaults, SDUI registry, fault
   injection, Security Rules + Remote Config template.
3. **US1** auth/onboarding (+ batch de aprovisionamiento) → **US2** accounts →
   **E2E crítico** (cierra el flujo principal temprano).
4. **US3** personalización → **US4** fx → **US5** notificaciones + `tools/admin`.
5. **Pulido**: accesibilidad, docs (ADRs, arquitectura, operación, ai-usage), README.

## Complexity Tracking

Sin violaciones de la constitución; no aplica.
