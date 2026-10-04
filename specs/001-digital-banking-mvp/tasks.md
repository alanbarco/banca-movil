---

description: "Task list for MVP Banca Móvil Digital Personalizada"
---

# Tasks: MVP Banca Móvil Digital Personalizada

**Input**: Design documents from `/specs/001-digital-banking-mvp/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: INCLUIDAS. Son obligatorias por la constitución (Principio V: unit, widget, E2E) y
por la spec (SC-012). Dentro de cada historia, las pruebas se listan primero; se escriben
junto con (o antes de) la implementación y deben quedar en verde al cerrar la historia.

**Organization**: Tareas agrupadas por historia de usuario para implementarlas y probarlas de
forma independiente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Paralelizable (archivos distintos, sin dependencias pendientes)
- **[Story]**: Historia a la que pertenece (US1…US5)
- Rutas relativas a la raíz del repo. Paquete Dart: `bi_app` (nombre visible: "BI App"). Proyecto Firebase:
  `bi-app-ae0d1`.

## Path Conventions

- App Flutter en la raíz: `lib/{app,core,features}`, pruebas en `test/` (espejo de `lib/`) e
  `integration_test/`.
- Cada feature: `lib/features/<feature>/{domain,data,presentation}`.
- Configuración Firebase como código en `firebase/`; herramientas del banco en `tools/admin/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Inicializar el proyecto Flutter, Firebase, lints y CI.

- [X] T001 Crear el proyecto Flutter en la raíz del repo con `flutter create --org com.alanbarco --project-name bi_app --platforms android,ios .` (conservar `.specify/`, `specs/`, `.gitignore` existentes; fusionar el `.gitignore` generado con el actual)
- [X] T002 Configurar `pubspec.yaml`: dependencias `flutter_bloc`, `bloc`, `equatable`, `go_router`, `get_it`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_remote_config`, `firebase_messaging`, `firebase_crashlytics`, `firebase_analytics`, `dio`, `shared_preferences`, `connectivity_plus`, `intl`; dev: `flutter_lints`, `bloc_test`, `mocktail`, `fake_cloud_firestore`, `fake_async`, `integration_test` (sdk); declarar asset `assets/config/`
- [X] T003 [P] Configurar `analysis_options.yaml` (incluir `package:flutter_lints/flutter.yaml` + reglas `prefer_const_constructors`, `prefer_final_locals`, `always_declare_return_types`, `avoid_print`, `require_trailing_commas`)
- [X] T004 [P] Crear `.gitattributes` con `* text=auto eol=lf` y `*.png binary`, `*.jpg binary`, `*.jar binary`
- [X] T005 [P] Crear `firebase.json` (firestore rules `firebase/firestore.rules`, indexes `firebase/firestore.indexes.json`, remoteconfig template `firebase/remoteconfig.template.json`) y `.firebaserc` con proyecto default `bi-app-ae0d1`
- [X] T006 Ejecutar `flutterfire configure --project=bi-app-ae0d1 --platforms=android` para generar `lib/firebase_options.dart` y `android/app/google-services.json`; agregar plugins Gradle de Google Services y Crashlytics en `android/settings.gradle(.kts)` y `android/app/build.gradle(.kts)`. Después, mover las claves a `.env` (ignorado; plantilla `.env.example`): `firebase_options.dart` las lee con `String.fromEnvironment` (`--dart-define-from-file=.env`), `google-services.json` queda ignorado y CI los reconstruye desde los secrets `FIREBASE_ENV` y `GOOGLE_SERVICES_JSON`
- [X] T007 Configurar Android en `android/app/build.gradle(.kts)` (`minSdk = 26`) y `android/app/src/main/AndroidManifest.xml` (permisos `INTERNET`, `POST_NOTIFICATIONS`; label "BI App")
- [X] T008 [P] Crear `tool/check_coverage.dart`: lee `coverage/lcov.info`, calcula cobertura de líneas solo para archivos bajo `lib/**/domain/**` y `lib/**/presentation/bloc/**` y termina con código 1 si es < 70 %
- [X] T009 [P] Crear `.github/workflows/ci.yml` (push y PR a `main`, ubuntu-latest, `subosito/flutter-action` canal stable): `flutter pub get` → `dart format --set-exit-if-changed .` → `flutter analyze` → `flutter test --coverage` → `dart run tool/check_coverage.dart` → `flutter build apk --debug`

**Checkpoint**: `flutter run` muestra la app por defecto conectada a Firebase; CI en verde.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infraestructura de `core` y `app` que todas las historias necesitan.

**⚠️ CRITICAL**: Ninguna historia puede empezar hasta completar esta fase.

### Tests de la fase fundacional

- [X] T010 [P] Test de `Result`/`Failure` en `test/core/error/result_test.dart` (fold, map, igualdad)
- [X] T011 [P] Test del interceptor de reintentos en `test/core/network/retry_interceptor_test.dart`: reintenta 3 veces solo GET con esperas 0.5 s/1 s/2 s ante timeout/5xx/error de conexión; no reintenta 4xx ni POST
- [X] T012 [P] Test del parser SDUI en `test/core/sdui/home_section_parser_test.dart`: omite `type` desconocido y payloads inválidos devolviendo la lista de omitidas; rechaza `schemaVersion` > 1
- [X] T013 [P] Test de evaluación de flags en `test/core/flags/feature_flags_test.dart`: `segments` vacío = todos; flag ausente = default local; flag deshabilitado
- [X] T014 [P] Test de `SessionTimeoutService` en `test/core/session/session_timeout_service_test.dart` (con `fake_async`: vence a los 5 min sin interacción; `registerInteraction()` reinicia)
- [X] T015 [P] Test de `ConnectivityCubit` en `test/core/connectivity/connectivity_cubit_test.dart` (online → offline → online, emite evento `connectivity_changed`)
- [X] T016 [P] Test de redacción de PII del logger en `test/core/observability/app_logger_test.dart` (enmascara correos, montos y números de ≥ 8 dígitos)

### Implementación fundacional

- [X] T017 [P] Crear `Result<T>` sealed (`Success`, `Err`) en `lib/core/error/result.dart` y `Failure` sealed (`network`, `timeout`, `unauthorized`, `notFound`, `validation(field)`, `server`, `unknown`) en `lib/core/error/failure.dart`
- [X] T018 [P] Crear `DataSnapshot<T>` (`data`, `isStale`, `lastSyncedAt`) en `lib/core/data/data_snapshot.dart` y `LoadState` reutilizable (initial/loading/success/stale/empty/failure) en `lib/core/data/load_status.dart`
- [X] T019 [P] Crear interfaz `ObservabilityService` (`logEvent`, `recordError`, `setUserProperty`, `setUserId`) en `lib/core/observability/observability_service.dart`, constantes de eventos según `contracts/analytics-events.md` en `lib/core/observability/analytics_events.dart` y logger estructurado con redacción de PII en `lib/core/observability/app_logger.dart`
- [X] T020 Implementar `FirebaseObservabilityService` (Analytics + Crashlytics; no-op en tests) en `lib/core/observability/firebase_observability_service.dart`
- [X] T021 [P] Crear wrapper `LocalStorage` sobre `shared_preferences` (get/set string, bool, JSON, remove) en `lib/core/storage/local_storage.dart`
- [X] T022 [P] Crear `ConnectivityCubit` + estado en `lib/core/connectivity/connectivity_cubit.dart` usando `connectivity_plus` y respetando el modo offline forzado del simulador
- [X] T023 [P] Crear modelo de simulación en `lib/core/fault_injection/fault_config.dart` (`FaultTarget { firestore, personalization, fx }`, `FaultMode { none, offline, latency, error }`, `latencyMs`) y `FaultInjectionCubit` en `lib/core/fault_injection/fault_injection_cubit.dart`; el modo `offline` de `firestore` llama `FirebaseFirestore.instance.disableNetwork()`/`enableNetwork()`
- [X] T024 Crear helper `runWithFaults<T>(FaultTarget, Future<T> Function())` y `streamWithFaults<T>` (aplica latencia o lanza error simulado) en `lib/core/fault_injection/fault_runner.dart`
- [X] T025 [P] Crear `DioFactory` (timeout desde parámetro, base URL dinámica) en `lib/core/network/dio_factory.dart`, `RetryInterceptor` en `lib/core/network/retry_interceptor.dart` y `FaultInterceptor` (target `fx`) en `lib/core/network/fault_interceptor.dart`
- [X] T026 [P] Crear `assets/config/remote_config_defaults.json` con `home_layout`, `feature_flags`, `onboarding_seed`, `fx_config` y `terms` exactamente según `contracts/remote-config.md` (layouts para `default`, `student`, `professional`, `entrepreneur`; cada uno incluye `accounts_summary` en `order: 0`)
- [X] T027 Crear `RemoteConfigService` en `lib/core/flags/remote_config_service.dart`: `setDefaults` desde el asset, `fetchAndActivate` (intervalo mínimo 0 en debug, 5 min en release), stream de `onConfigUpdated` → `activate()`, `getJson(key)` con validación de `schemaVersion`
- [X] T028 Crear contrato `FeatureFlagService` (`isEnabled(key, {segment})`, `changes` stream) en `lib/core/flags/feature_flag_service.dart`, claves en `lib/core/flags/flag_keys.dart` (`fx_service`, `offers`, `push_opt_in_prompt`, `demo_fault_panel`) e implementación en `lib/core/flags/remote_config_feature_flag_service.dart`
- [X] T029 [P] Crear `HomeSection` (`id`, `type`, `order`, `interests`, `flag`, `payload`) y parser tolerante en `lib/core/sdui/home_section.dart` y `lib/core/sdui/home_section_parser.dart`; tipos válidos: `accounts_summary`, `banner`, `offer_carousel`, `quick_actions`, `tip`
- [X] T030 [P] Crear `SectionRegistry` (`register(type, builder)`, `build(context, section)` → `Widget?`) en `lib/core/sdui/section_registry.dart`
- [X] T031 [P] Crear contrato `CurrentUserProfile` (stream de `SessionUser { uid, segment, interests }`) en `lib/core/session/current_user_profile.dart` y `SessionEvents` (stream `signedIn(uid, segment)` / `signingOut(uid)` / `segmentChanged(old, new)`) en `lib/core/session/session_events.dart`
- [X] T032 [P] Crear `SessionTimeoutService` (5 min, `registerInteraction()`, stream `timeouts`) en `lib/core/session/session_timeout_service.dart`
- [X] T033 [P] Crear `AppRoutes` (constantes de `contracts/ui-routes.md` + validación `isKnown(route)`) en `lib/core/routing/app_routes.dart` y `PendingRouteStore` en `lib/core/routing/pending_route_store.dart`
- [X] T034 [P] Crear tema y design system en `lib/core/ui/theme.dart` (naranja corporativo, contraste AA, `textTheme` escalable, botones mín. 48 dp)
- [X] T035 [P] Crear widgets de estado en `lib/core/ui/widgets/`: `skeleton.dart`, `error_view.dart` (mensaje + botón "Reintentar"), `empty_view.dart`, `stale_data_banner.dart` ("Sin conexión · actualizado a las HH:mm"), `offline_banner.dart`; todos con `Semantics`
- [X] T036 [P] Crear `BalanceVisibilityCubit` persistido en `LocalStorage` (clave `hide_balances`) en `lib/core/ui/balance_visibility_cubit.dart` y `MoneyText` (formato `es_EC` USD desde centavos, muestra `••••` si está oculto, `Semantics` con monto o "saldo oculto") en `lib/core/ui/widgets/money_text.dart`
- [X] T037 [P] Crear `firebase/firestore.rules` según `contracts/firestore-security.md` (matriz de acceso, condición de batch de onboarding con `!exists`/`existsAfter`, límites: cuenta `0 ≤ balanceCents ≤ 1_000_000`, movimiento `0 < amountCents ≤ 500_000`, `currency == 'USD'`, `type` en catálogo; `fullName` 3–80; `segment` en `student|professional|entrepreneur`; `interests` 1–5) y `firebase/firestore.indexes.json` vacío
- [X] T038 [P] Crear `firebase/remoteconfig.template.json` con los mismos parámetros y valores que `assets/config/remote_config_defaults.json`
- [X] T039 Crear `lib/app/di.dart` (get_it: `LocalStorage`, `ObservabilityService`, `RemoteConfigService`, `FeatureFlagService`, `SectionRegistry`, `SessionTimeoutService`, `SessionEvents`, `FaultInjectionCubit`, `DioFactory`; función `registerFeatures()` que invoca el módulo de cada feature)
- [X] T040 Crear `lib/app/router.dart` (GoRouter con `/splash`, composición de listas de rutas de features, `redirect` por autenticación/flags/rutas pendientes) y `lib/app/shell/app_shell.dart` (Scaffold con `NavigationBar` Inicio/Divisas/Perfil, `OfflineBanner`, `Listener` raíz que llama `registerInteraction()`)
- [X] T041 Crear `lib/app/app.dart` (`MaterialApp.router`, tema, `MultiBlocProvider` global: `ConnectivityCubit`, `BalanceVisibilityCubit`, `FaultInjectionCubit`) y `lib/main.dart` (init Firebase; si `pending_cache_clear` en `LocalStorage` → `FirebaseFirestore.instance.clearPersistence()` antes de cualquier lectura; `Settings(persistenceEnabled: true)`; handlers `FlutterError.onError` y `PlatformDispatcher.instance.onError` → Crashlytics; init Remote Config; DI; `runApp`); `DEMO_TOOLS` leído con `bool.fromEnvironment`
- [X] T042 Desplegar configuración: `firebase deploy --only firestore:rules,firestore:indexes,remoteconfig` (documentar salida en el PR/commit)

**Checkpoint**: App arranca en `/splash`, con tema, banner offline funcional, Remote Config cargado y reglas desplegadas.

---

## Phase 3: User Story 1 - Onboarding y autenticación (Priority: P1) 🎯 MVP

**Goal**: Registro con perfil/segmento y apertura automática de cuenta; login, sesión
persistente, logout, recuperación de contraseña e inactividad.

**Independent Test**: quickstart V1, V2, V3, V16 — registrar cliente nuevo, reabrir app,
esperar inactividad, cerrar sesión, recuperar contraseña.

### Tests for User Story 1

- [X] T043 [P] [US1] Test del caso de uso `RegisterCustomer` en `test/features/auth/domain/register_customer_test.dart` (valida contraseña ≥ 8 con letras y números, términos aceptados, segmento y 1–5 intereses; propaga `Failure.validation('email')`)
- [X] T044 [P] [US1] Test del aprovisionamiento en `test/features/auth/data/customer_provisioning_datasource_test.dart` con `fake_cloud_firestore`: crea en un batch `users/{uid}`, una cuenta `savings` con número de 10 dígitos y `currency: 'USD'`, y los movimientos de `onboarding_seed`; el `balanceAfterCents` del movimiento más reciente == `balanceCents` de la cuenta
- [X] T045 [P] [US1] Test de `AuthRepositoryImpl` en `test/features/auth/data/auth_repository_impl_test.dart`: mapea `email-already-in-use` → `validation('email')`, `invalid-credential`/`wrong-password`/`user-not-found` → `unauthorized` (mensaje genérico), `network-request-failed` → `network`
- [X] T046 [P] [US1] Test de `AuthBloc` en `test/features/auth/presentation/bloc/auth_bloc_test.dart` (unknown → authenticated / needsOnboarding / unauthenticated; logout; timeout de sesión emite `session_timeout` y vuelve a unauthenticated)
- [X] T047 [P] [US1] Test de `OnboardingCubit` en `test/features/auth/presentation/bloc/onboarding_cubit_test.dart` (avanza pasos, no avanza sin términos, conserva datos tras error de red, emite `onboarding_step_viewed`/`onboarding_abandoned`/`onboarding_completed`, ignora doble envío)
- [X] T048 [P] [US1] Test de `LoginCubit` en `test/features/auth/presentation/bloc/login_cubit_test.dart` (éxito, credenciales inválidas, red; correo precargado tras timeout)
- [X] T049 [P] [US1] Widget test en `test/features/auth/presentation/pages/login_page_test.dart` (carga deshabilita botón, error genérico visible, error de red con reintento)
- [X] T050 [P] [US1] Widget test en `test/features/auth/presentation/pages/register_flow_test.dart` (paso de términos bloquea "Continuar" hasta aceptar; error de correo junto al campo)

### Implementation for User Story 1

- [X] T051 [P] [US1] Crear entidades en `lib/features/auth/domain/entities/`: `user_profile.dart` (`fullName` 3–80, `email`, `segment`, `interests` 1–5, `notificationsEnabled`, `termsVersion`, `termsAcceptedAt`, `createdAt`), `segment.dart` (`student | professional | entrepreneur`), `interest.dart` (`savings`, `investment`, `travel`, `education`, `business`), `registration_data.dart`, `onboarding_seed.dart`
- [X] T052 [US1] Crear contrato `AuthRepository` en `lib/features/auth/domain/repositories/auth_repository.dart` (`authState` stream, `signIn`, `register(RegistrationData)`, `completeProfile` para usuario autenticado sin perfil, `signOut`, `sendPasswordReset`, `watchProfile`, `updateInterests`, `updateNotificationsEnabled`)
- [X] T053 [P] [US1] Crear casos de uso en `lib/features/auth/domain/usecases/`: `sign_in.dart`, `register_customer.dart` (validaciones FR-002/FR-003), `send_password_reset.dart` (cerrar sesión y observar la sesión van directo al repositorio: solo hay caso de uso cuando hay lógica)
- [X] T054 [P] [US1] Crear `FirebaseAuthDatasource` en `lib/features/auth/data/datasources/firebase_auth_datasource.dart`
- [X] T055 [P] [US1] Crear `OnboardingSeedDatasource` (lee `onboarding_seed` de `RemoteConfigService`) en `lib/features/auth/data/datasources/onboarding_seed_datasource.dart`
- [X] T056 [US1] Crear `CustomerProvisioningDatasource` en `lib/features/auth/data/datasources/customer_provisioning_datasource.dart`: un único `WriteBatch` con perfil (`createdAt`/`termsAcceptedAt` = `FieldValue.serverTimestamp()`), cuenta y movimientos (`date` = ahora − `daysAgo`, `balanceAfterCents` acumulado) según `contracts/firestore-security.md`
- [X] T057 [P] [US1] Crear `UserProfileModel` (map ↔ entidad) en `lib/features/auth/data/models/user_profile_model.dart` y `UserProfileDatasource` (watch/update de `users/{uid}`) en `lib/features/auth/data/datasources/user_profile_datasource.dart`
- [X] T058 [US1] Implementar `AuthRepositoryImpl` en `lib/features/auth/data/repositories/auth_repository_impl.dart` (mapeo de errores, registro = crear usuario Auth + aprovisionamiento; si el aprovisionamiento falla, estado `needsOnboarding` para reintentar con `completeProfile`); implementa también `CurrentUserProfile` de core y publica `SessionEvents`
- [X] T059 [US1] Crear `AuthBloc` en `lib/features/auth/presentation/bloc/auth_bloc.dart` (estados `unknown`, `needsOnboarding`, `authenticated(profile)`, `unauthenticated(prefillEmail?)`; escucha `SessionTimeoutService.timeouts`; en logout: `SessionEvents.signingOut`, marca `pending_cache_clear`, guarda último correo; `setUserProperty('segment')`)
- [X] T060 [P] [US1] Crear `LoginCubit` en `lib/features/auth/presentation/bloc/login_cubit.dart` y `ForgotPasswordCubit` en `lib/features/auth/presentation/bloc/forgot_password_cubit.dart` (mensaje de confirmación que no revela si el correo existe)
- [X] T061 [US1] Crear `OnboardingCubit` en `lib/features/auth/presentation/bloc/onboarding_cubit.dart` (pasos `credentials → profile → interests → terms → submitting → done`; conserva datos excepto contraseña ante error)
- [X] T062 [P] [US1] Crear `lib/features/auth/presentation/pages/login_page.dart` y `lib/features/auth/presentation/pages/forgot_password_page.dart`
- [X] T063 [US1] Crear flujo de registro en `lib/features/auth/presentation/pages/register_page.dart` con pasos en `lib/features/auth/presentation/widgets/` (`credentials_step.dart`, `segment_step.dart`, `interests_step.dart`, `terms_step.dart` con enlace a `terms.url`), indicador de progreso accesible
- [X] T064 [US1] Crear `lib/features/auth/presentation/pages/profile_page.dart` (datos del cliente, cerrar sesión; secciones de intereses y notificaciones se completan en US3/US5)
- [X] T065 [US1] Crear `lib/features/auth/auth_routes.dart` (`/login`, `/register`, `/forgot-password`, `/profile`) y `lib/features/auth/auth_module.dart` (registro en get_it); conectar `AuthBloc` al `redirect` de `lib/app/router.dart` y `/splash`

**Checkpoint**: Un cliente nuevo se registra y queda con cuenta y movimientos en Firestore; login/logout/recuperación/inactividad funcionan.

---

## Phase 4: User Story 2 - Cuentas, saldos y movimientos (Priority: P2)

**Goal**: Resumen de cuentas, ocultar saldos, detalle con movimientos paginados, actualización
en tiempo real y datos de caché con indicador.

**Independent Test**: quickstart V4, V5, V12, V13 y el E2E V19.

### Tests for User Story 2

- [X] T066 [P] [US2] Test de entidades en `test/features/accounts/domain/account_test.dart` (`maskedNumber` = `•••• ` + últimos 4; `Movement.isCredit`)
- [X] T067 [P] [US2] Test de `AccountsRepositoryImpl` en `test/features/accounts/data/accounts_repository_impl_test.dart` con `fake_cloud_firestore` (orden `date` desc, `limit(20)`, paginación con `startAfterDocument`, `isStale` según metadata, `lastSyncedAt` guardado)
- [X] T068 [P] [US2] Test de `AccountsCubit` en `test/features/accounts/presentation/bloc/accounts_cubit_test.dart` (loading → success / stale / empty / failure → retry; evento `stale_data_shown` y `data_load_error`)
- [X] T069 [P] [US2] Test de `MovementsBloc` en `test/features/accounts/presentation/bloc/movements_bloc_test.dart` (primera página en vivo, `loadMore`, fin de lista, nuevo movimiento entrante)
- [X] T070 [P] [US2] Widget test en `test/features/accounts/presentation/pages/account_detail_page_test.dart` (skeleton, lista, vacío, error con reintento, banner de datos desactualizados, saldos ocultos)

### Implementation for User Story 2

- [X] T071 [P] [US2] Crear entidades `Account` (`type` `savings|checking`, `number` 10 dígitos, `currency` `USD`, `balanceCents` ≥ 0, `openedAt`, `updatedAt`, `maskedNumber`) y `Movement` (`date`, `description` 1–60, `amountCents` > 0, `type` `credit|debit`, `balanceAfterCents`) en `lib/features/accounts/domain/entities/`
- [X] T072 [US2] Crear contrato `AccountsRepository` (`watchAccounts(uid)`, `watchAccount(uid, accountId)`, `watchRecentMovements(uid, accountId)`, `fetchMoreMovements(uid, accountId, after)`) devolviendo `Result<DataSnapshot<…>>` en `lib/features/accounts/domain/repositories/accounts_repository.dart` y casos de uso en `lib/features/accounts/domain/usecases/`
- [X] T073 [P] [US2] Crear modelos `AccountModel`/`MovementModel` en `lib/features/accounts/data/models/`
- [X] T074 [US2] Crear `AccountsFirestoreDatasource` (`snapshots(includeMetadataChanges: true)`, ruta `users/{uid}/accounts/{accountId}/movements`, `orderBy('date', descending: true).limit(20)`) en `lib/features/accounts/data/datasources/accounts_firestore_datasource.dart` y `LastSyncStore` en `lib/features/accounts/data/datasources/last_sync_store.dart`
- [X] T075 [US2] Implementar `AccountsRepositoryImpl` envuelto con `streamWithFaults(FaultTarget.firestore, …)` en `lib/features/accounts/data/repositories/accounts_repository_impl.dart`
- [X] T076 [P] [US2] Crear `AccountsCubit` en `lib/features/accounts/presentation/bloc/accounts_cubit.dart` y `MovementsBloc` en `lib/features/accounts/presentation/bloc/movements_bloc.dart` (obtienen `uid` de `CurrentUserProfile`)
- [X] T077 [P] [US2] Crear widgets `account_card.dart` (tipo, `maskedNumber`, `MoneyText`, `Semantics` completo) y `movement_tile.dart` (ingreso/egreso con ícono + signo, no solo color) en `lib/features/accounts/presentation/widgets/`
- [X] T078 [US2] Crear `accounts_summary_section.dart` (lista de cuentas + toggle ocultar saldos) en `lib/features/accounts/presentation/widgets/` y registrarlo como tipo `accounts_summary` en `SectionRegistry` desde `lib/features/accounts/accounts_module.dart`
- [X] T079 [US2] Crear `lib/features/accounts/presentation/pages/account_detail_page.dart` (encabezado con saldo, lista paginada, estados de carga/vacío/error/stale) y `lib/features/accounts/accounts_routes.dart` (`/accounts/:accountId`)
- [X] T080 [US2] Crear `HomePage` interina en `lib/features/personalization/presentation/pages/home_page.dart` que renderiza la sección `accounts_summary` vía `SectionRegistry` y registrar `/home` en `lib/features/personalization/personalization_routes.dart` (se reemplaza en US3)
- [X] T081 [US2] Crear E2E en `integration_test/critical_flow_test.dart`: registra `e2e+<timestamp>@<dominio de prueba>` → completa onboarding → ve cuenta con saldo en inicio → abre detalle → ve ≥ 3 movimientos (SC-012)

**Checkpoint**: Flujo crítico registro → cuentas → movimientos funcionando y automatizado.

---

## Phase 5: User Story 3 - Personalización dinámica (Priority: P3)

**Goal**: Inicio SDUI por segmento/intereses, flags por segmento, cambios sin release,
edición de intereses.

**Independent Test**: quickstart V6, V7, V8, V9.

### Tests for User Story 3

- [X] T082 [P] [US3] Test de `ResolveHomeLayout` en `test/features/personalization/domain/resolve_home_layout_test.dart` (segmento → `default` → defaults locales; filtra por flag; ordena por `order` y prioriza intereses; omite tipos desconocidos y reporta `sdui_section_skipped`)
- [X] T083 [P] [US3] Test de `HomeLayoutCubit` en `test/features/personalization/presentation/bloc/home_layout_cubit_test.dart` (re-emite al recibir `onConfigUpdated` y al cambiar intereses; falla de personalización → último layout conocido)
- [X] T084 [P] [US3] Widget test en `test/features/personalization/presentation/pages/home_page_test.dart` (renderiza secciones registradas; sección inválida no rompe la pantalla)

### Implementation for User Story 3

- [X] T085 [P] [US3] Crear entidad `HomeLayout` y contrato `HomeLayoutRepository` (`watchLayout()`) en `lib/features/personalization/domain/` y caso de uso `ResolveHomeLayout` en `lib/features/personalization/domain/usecases/resolve_home_layout.dart`
- [X] T086 [US3] Crear `HomeLayoutRemoteConfigDatasource` (lee `home_layout`, escucha actualizaciones) en `lib/features/personalization/data/datasources/` y `HomeLayoutRepositoryImpl` envuelto con `FaultTarget.personalization` en `lib/features/personalization/data/repositories/`
- [X] T087 [US3] Crear `HomeLayoutCubit` en `lib/features/personalization/presentation/bloc/home_layout_cubit.dart` (combina `CurrentUserProfile` + layout + `FeatureFlagService.changes`)
- [X] T088 [P] [US3] Crear secciones en `lib/features/personalization/presentation/widgets/`: `banner_section.dart` (imagen por URL con `errorBuilder` a color/ícono), `offer_carousel_section.dart`, `quick_actions_section.dart` (oculta acciones con `flag` apagado), `tip_section.dart`; registrarlas en `SectionRegistry` desde `lib/features/personalization/personalization_module.dart`
- [X] T089 [US3] Reemplazar la `HomePage` interina por la versión SDUI completa en `lib/features/personalization/presentation/pages/home_page.dart` (pull-to-refresh, skeleton, layout desde caché si falla)
- [X] T090 [P] [US3] Crear `lib/features/personalization/presentation/pages/offer_detail_page.dart` y ruta `/offers/:offerId` (flag `offers`) en `lib/features/personalization/personalization_routes.dart`
- [X] T091 [US3] Agregar edición de intereses (1–5 del catálogo) en `lib/features/auth/presentation/pages/profile_page.dart` usando `AuthRepository.updateInterests` y emitir `SessionEvents.segmentChanged` si cambia el segmento
- [X] T092 [US3] Aplicar guardas de flags en el `redirect` de `lib/app/router.dart` (ruta con flag apagado → `/home`) y ocultar la pestaña Divisas en `lib/app/shell/app_shell.dart` según `fx_service`

**Checkpoint**: Clientes de segmentos distintos ven inicios distintos; cambios en Remote Config se reflejan sin reinstalar.

---

## Phase 6: User Story 4 - Servicio externo de tipos de cambio (Priority: P4)

**Goal**: Tasas USD de Frankfurter, conversor, caché y aislamiento ante fallos.

**Independent Test**: quickstart V10, V11.

### Tests for User Story 4

- [ ] T093 [P] [US4] Test de `ConvertCurrency` en `test/features/fx/domain/convert_currency_test.dart` (USD→X, X→USD, X→Y; redondeo 2 decimales, JPY 0)
- [ ] T094 [P] [US4] Test de `FxRepositoryImpl` en `test/features/fx/data/fx_repository_impl_test.dart` (éxito guarda caché; falla con caché → `isStale`; falla sin caché → `Failure`; `base` ≠ USD = inválida; emite `fx_service_failure` con `reason`)
- [ ] T095 [P] [US4] Test de `FxCubit` en `test/features/fx/presentation/bloc/fx_cubit_test.dart` y widget test en `test/features/fx/presentation/pages/fx_page_test.dart` (tasas con fecha, conversión, stale + reintentar, error sin caché)

### Implementation for User Story 4

- [ ] T096 [P] [US4] Crear entidad `ExchangeRates` (`base`, `date`, `rates`, `fetchedAt`, `isStale`), contrato `FxRepository` y caso de uso `ConvertCurrency` en `lib/features/fx/domain/`
- [ ] T097 [US4] Crear `FxRemoteDatasource` (GET `{baseUrl}/latest?base=USD&symbols=…` desde `fx_config`; verificar nombres de query params vigentes de Frankfurter) con `dio` + `RetryInterceptor` + `FaultInterceptor` en `lib/features/fx/data/datasources/fx_remote_datasource.dart` y `FxLocalCache` en `lib/features/fx/data/datasources/fx_local_cache.dart`
- [ ] T098 [US4] Implementar `FxRepositoryImpl` en `lib/features/fx/data/repositories/fx_repository_impl.dart` según la política de `contracts/fx-external-api.md`
- [ ] T099 [US4] Crear `FxCubit` en `lib/features/fx/presentation/bloc/fx_cubit.dart` y `lib/features/fx/presentation/pages/fx_page.dart` (lista de tasas con fecha, conversor con selector de divisas y tasa usada, banner stale, reintentar)
- [ ] T100 [US4] Crear `lib/features/fx/fx_routes.dart` (`/fx`, flag `fx_service`) y `lib/features/fx/fx_module.dart`

**Checkpoint**: Divisas funciona; con FX en modo error, la app sigue operativa y muestra caché.

---

## Phase 7: User Story 5 - Notificaciones push (Priority: P5)

**Goal**: Permiso explicado, topics por segmento, tokens por dispositivo, deep links,
aviso in-app, baja al cerrar sesión, herramientas de envío.

**Independent Test**: quickstart V5 (push de movimiento), V14, V15, V16.

### Tests for User Story 5

- [ ] T101 [P] [US5] Test de `NotificationsRepositoryImpl` en `test/features/notifications/data/notifications_repository_impl_test.dart` (al `signedIn`: guarda token y suscribe `all` + `segment_<segmento>`; `segmentChanged` des-suscribe el anterior; `signingOut` des-suscribe, borra `devices/{token}` y `deleteToken()`)
- [ ] T102 [P] [US5] Test de `ResolvePushRoute` en `test/features/notifications/domain/resolve_push_route_test.dart` (ruta conocida → ruta; desconocida → `/home`; sin sesión → guarda en `PendingRouteStore`)
- [ ] T103 [P] [US5] Test de `NotificationsCubit` en `test/features/notifications/presentation/bloc/notifications_cubit_test.dart` (explicación previa una sola vez, respeta denegación, mensaje en primer plano emite aviso, `push_opened`)

### Implementation for User Story 5

- [ ] T104 [P] [US5] Crear entidad `PushMessage` (`title`, `body`, `type` `movement|offer|announcement`, `route`), contrato `NotificationsRepository` y caso de uso `ResolvePushRoute` en `lib/features/notifications/domain/`
- [ ] T105 [US5] Crear `FcmDatasource` (permiso, token, `onTokenRefresh`, topics, `onMessage`, `onMessageOpenedApp`, `getInitialMessage`) y `DevicesDatasource` (`users/{uid}/devices/{token}` con `platform`, `createdAt`, `lastSeenAt`) en `lib/features/notifications/data/datasources/`
- [ ] T106 [US5] Implementar `NotificationsRepositoryImpl` escuchando `SessionEvents` en `lib/features/notifications/data/repositories/notifications_repository_impl.dart`
- [ ] T107 [US5] Crear `NotificationsCubit` en `lib/features/notifications/presentation/bloc/notifications_cubit.dart`, `permission_explainer_dialog.dart` (flag `push_opt_in_prompt`) y `in_app_notification_listener.dart` (`MaterialBanner` con acción "Ver") en `lib/features/notifications/presentation/widgets/`
- [ ] T108 [US5] Integrar en la app: handler de background en `lib/main.dart`, `InAppNotificationListener` en `lib/app/shell/app_shell.dart`, navegación por deep link y `PendingRouteStore` en `lib/app/router.dart`, metadato de canal por defecto en `android/app/src/main/AndroidManifest.xml`; registrar en `lib/features/notifications/notifications_module.dart`
- [ ] T109 [US5] Agregar interruptor de notificaciones en `lib/features/auth/presentation/pages/profile_page.dart` (actualiza `preferences.notificationsEnabled` y permiso)
- [ ] T110 [P] [US5] Crear `tools/admin/package.json` (Node LTS, `firebase-admin`, `minimist`), `tools/admin/add-movement.js` (transacción: crea movimiento, actualiza `balanceCents`/`updatedAt`, valida saldo ≥ 0, envía push `type=movement` con `route=/accounts/{id}` a los tokens del cliente), `tools/admin/send-push.js` (`--topic --title --body --route`) y `tools/admin/README.md`; credencial `tools/admin/service-account.json` no versionada

**Checkpoint**: Push por segmento y personal funcionando; tocar la notificación abre la pantalla correcta.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Simulador de fallos, accesibilidad, documentación y validación final.

- [ ] T111 Crear `lib/core/fault_injection/presentation/fault_panel_page.dart` (por cada `FaultTarget`: normal / sin conexión / latencia con slider / error) en ruta `/debug/faults`, visible solo con `DEMO_TOOLS=true` y flag `demo_fault_panel`; acceso desde `profile_page.dart`
- [ ] T112 [P] Widget test de accesibilidad en `test/accessibility/text_scale_test.dart` (inicio, detalle de cuenta y divisas con `textScaler` 2.0 sin overflow; `meetsGuideline(androidTapTargetGuideline)` y `labeledTapTargetGuideline`)
- [ ] T113 Revisión de accesibilidad y contraste en `lib/core/ui/` y widgets de features (etiquetas `Semantics` en montos, íconos y botones; orden de foco)
- [ ] T114 [P] Escribir ADRs en `docs/adr/`: `001-firebase-backend.md`, `002-onboarding-provisioning-batch.md`, `003-sdui-remote-config.md`, `004-fx-external-service.md`, `005-resilience-fault-injection.md`, `006-feature-first-to-packages.md` (problema, alternativas, decisión, trade-offs, impacto largo plazo; fuente: `research.md`)
- [ ] T115 [P] Escribir `docs/architecture.md` con diagramas Mermaid: componentes (`app`/`core`/`features`), regla de dependencias, secuencia de onboarding con batch, flujo offline/stale, flujo de push y deep link; supuestos, riesgos técnicos y estrategia de escalamiento
- [ ] T116 [P] Escribir `docs/operations.md`: despliegue (Firebase CLI, build APK, distribución gratuita con Firebase App Distribution), monitoreo (Crashlytics, alertas de velocidad, Analytics funnels/DebugView), detección de problemas de UX, comportamiento ante conectividad limitada/latencia/caídas, runbook de incidentes
- [ ] T117 [P] Escribir `docs/ai-usage.md`: herramientas (Claude Code + Spec Kit), flujo constitución → spec → plan → tasks → implement, ejemplos concretos, impacto en productividad, calidad, documentación y pruebas, límites y verificaciones humanas
- [ ] T118 Escribir `README.md`: descripción, capturas, requisitos, configuración (enlace a `specs/001-digital-banking-mvp/quickstart.md`), ejecutar, probar, demo (panel de fallos, `tools/admin`), estructura, cómo se diseñó (enlaces a `specs/` y `docs/`), flujo TBD y convención de commits
- [ ] T119 Ejecutar `dart format`, `flutter analyze`, `flutter test --coverage` y `dart run tool/check_coverage.dart`; corregir hasta pasar (≥ 70 %)
- [ ] T120 Ejecutar la validación manual V1–V20 de `specs/001-digital-banking-mvp/quickstart.md` en emulador/dispositivo y el E2E `flutter test integration_test`; registrar hallazgos como riesgos conocidos en `docs/operations.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias. T006 requiere `firebase login` y FlutterFire CLI instalados.
- **Foundational (Phase 2)**: depende de Setup; BLOQUEA todas las historias. T042 depende de T037–T038.
- **US1 (Phase 3)**: depende de Foundational.
- **US2 (Phase 4)**: depende de Foundational y, para datos reales, de US1 (cuentas creadas en el onboarding). T081 (E2E) depende de US1 + US2.
- **US3 (Phase 5)**: depende de Foundational; T089 reemplaza T080 (US2); T091 extiende la página de perfil de US1.
- **US4 (Phase 6)**: depende solo de Foundational (+ sesión de US1 para navegar).
- **US5 (Phase 7)**: depende de Foundational y de `SessionEvents` publicados por US1; T110 usa la estructura de datos de US2.
- **Polish (Phase 8)**: depende de las historias que se entreguen.

### User Story Dependencies

```text
Setup → Foundational → US1 → US2 → (E2E T081)
                         │
                         ├──► US3 (reemplaza home interina)
                         ├──► US4 (independiente)
                         └──► US5 (usa SessionEvents)
                                     ↓
                                   Polish
```

### Within Each User Story

- Tests y entidades/contratos primero → datasources/modelos → repositorio → BLoC/Cubit →
  páginas/widgets → rutas y módulo DI.
- La historia se cierra con sus tests en verde y su checkpoint validado.

### Parallel Opportunities

- Setup: T003, T004, T005, T008, T009 en paralelo.
- Foundational: todos los tests T010–T016 y los [P] T017–T038 en paralelo (archivos distintos).
- Tras US1, US3/US4/US5 pueden avanzar en paralelo (archivos de features distintos), salvo las
  tareas que tocan `profile_page.dart`, `app_shell.dart` y `router.dart` (T091, T092, T108,
  T109), que deben hacerse en secuencia.

---

## Parallel Example: User Story 1

```text
# Tests de US1 en paralelo:
Task: "T043 Test RegisterCustomer en test/features/auth/domain/register_customer_test.dart"
Task: "T044 Test aprovisionamiento en test/features/auth/data/customer_provisioning_datasource_test.dart"
Task: "T046 Test AuthBloc en test/features/auth/presentation/bloc/auth_bloc_test.dart"

# Capa data de US1 en paralelo:
Task: "T054 FirebaseAuthDatasource"
Task: "T055 OnboardingSeedDatasource"
Task: "T057 UserProfileModel + UserProfileDatasource"
```

## Parallel Example: User Story 4

```text
Task: "T093 Test ConvertCurrency"
Task: "T094 Test FxRepositoryImpl"
Task: "T096 Entidad ExchangeRates + contrato + caso de uso"
```

---

## Implementation Strategy

### MVP First (ventana de 2 días)

**Día 1**
1. Phase 1 Setup + Phase 2 Foundational.
2. Phase 3 US1 → validar V1–V3, V16.
3. Phase 4 US2 + E2E T081 → validar V4, V5 (manual en consola si `tools/admin` aún no existe), V12, V19.
4. **STOP & VALIDATE**: el flujo crítico está completo y demostrable.

**Día 2**
5. Phase 5 US3 → V6–V9.
6. Phase 6 US4 → V10–V11.
7. Phase 7 US5 → V14–V16.
8. Phase 8 Polish: panel de fallos, accesibilidad, docs, README, validación final.

### Recorte si falta tiempo (en este orden)

1. `tools/admin` (T110): usar la consola de Firebase para movimientos y push.
2. Página de detalle de oferta (T090): las ofertas abren el inicio.
3. Test de accesibilidad automatizado (T112): mantener la revisión manual (T113).

Nunca recortar: tests de BLoC/casos de uso, E2E, simulador de fallos ni documentación (son
criterios de evaluación).

---

## Notes

- [P] = archivos distintos, sin dependencias pendientes.
- Commits pequeños y frecuentes en `main` (Trunk Based Development) con Conventional Commits,
  al cerrar cada tarea o grupo lógico; cada commit se propone al autor para su confirmación
  antes de crearse.
- Funcionalidad incompleta se integra oculta tras feature flag.
- Validar cada checkpoint antes de pasar a la siguiente fase.
