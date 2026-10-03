# Quickstart & Validation: MVP Banca Móvil Digital Personalizada

**Feature**: `001-digital-banking-mvp` | **Plan**: [plan.md](./plan.md)

Guía para configurar, ejecutar y **validar** el MVP de punta a punta. Todo es gratuito
(Firebase plan Spark, sin tarjeta).

## 1. Prerrequisitos

| Herramienta | Verificación |
|---|---|
| Flutter estable (Dart ≥ 3.6) | `flutter --version`, `flutter doctor` |
| Android Studio + emulador (API 33+) o dispositivo Android | `flutter devices` |
| Node.js LTS (para Firebase CLI y `tools/admin`) | `node --version` |
| Firebase CLI | `npm i -g firebase-tools` → `firebase --version` |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` |

## 2. Configuración de Firebase (una vez)

1. Crear proyecto en la consola de Firebase (plan **Spark**; Analytics habilitado).
2. **Authentication** → habilitar *Email/Password*.
3. **Firestore** → crear base en modo producción.
4. Credenciales locales (**no se versionan**):
   - Consola → Configuración del proyecto → Tus apps → app Android
     `com.alanbarco.bi_app` → descargar **`google-services.json`** a `android/app/`.
   - Copiar `.env.example` a `.env` y completar los valores de esa misma pantalla.
   - ⚠️ No ejecutar `flutterfire configure`: sobrescribe `lib/firebase_options.dart`, que lee
     las claves desde `.env`.
5. Desde la raíz del repo:
   ```powershell
   firebase login
   firebase use --add                     # seleccionar el proyecto
   firebase deploy --only firestore:rules,firestore:indexes,remoteconfig
   ```
6. (Opcional, herramientas del banco) Consola → Configuración → Cuentas de servicio →
   generar clave → guardar como `tools/admin/service-account.json` (**ignorado por git**).
   ```powershell
   cd tools/admin; npm install
   ```

## 3. Ejecutar

```powershell
flutter pub get
flutter run --dart-define-from-file=.env              # DEMO_TOOLS=true en .env → panel de fallos
flutter run --release --dart-define-from-file=.env    # con DEMO_TOOLS=false para la versión limpia
```

CI (GitHub Actions) reconstruye las credenciales desde los secrets `FIREBASE_ENV` (contenido
de `.env`) y `GOOGLE_SERVICES_JSON` (contenido de `android/app/google-services.json`).

## 4. Pruebas

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test --coverage                        # unit + widget
flutter test integration_test                  # E2E (requiere emulador y Firebase configurado)
```

## 5. Escenarios de validación

Referencias: [spec.md](./spec.md), [contracts/](./contracts/).

| # | Escenario | Pasos | Resultado esperado | Spec |
|---|---|---|---|---|
| V1 | Registro y cuenta automática | Registrarse con correo nuevo, segmento *student*, interés *education*, aceptar términos | Llega a inicio en < 3 min con cuenta de ahorros, saldo y 3 movimientos | US1, FR-004, SC-001 |
| V2 | Sesión persistente | Cerrar app (swipe) y reabrir | Sigue autenticado | US1-5 |
| V3 | Inactividad | No tocar la app 5 min | Vuelve al login con el correo precargado | FR-007 |
| V4 | Saldos ocultos | Tocar "ocultar saldos", reabrir app | Montos ocultos persistentes | FR-010 |
| V5 | Movimiento en vivo | `node tools/admin/add-movement.js --uid <uid> --account <id> --amount 25 --type credit --desc "Pago"` con la cuenta abierta | Movimiento y saldo nuevos en < 10 s + push | FR-012, SC-004 |
| V6 | Personalización por segmento | Iniciar sesión con un cliente *student* y otro *entrepreneur* | Inicios distintos | US3-1, SC-006 |
| V7 | Cambio sin release | En consola de Remote Config, reordenar secciones de *student* y publicar | Inicio se reordena sin reinstalar | FR-015, SC-005 |
| V8 | Flag por segmento | `feature_flags.fx_service.segments = ["professional"]` y publicar | *student* deja de ver Divisas; *professional* sí | US3-3, US4-5 |
| V9 | Sección inválida | Agregar sección `type: "video"` | Se omite, resto visible, evento `sdui_section_skipped` | FR-016 |
| V10 | Divisas | Abrir Divisas, convertir 100 USD → EUR | Tasas con fecha y monto convertido | US4-1/2 |
| V11 | Servicio externo caído | Panel demo → FX = error | Datos en caché marcados desactualizados + reintentar; cuentas siguen funcionando | FR-021/22, SC-008 |
| V12 | Sin conexión | Panel demo → Firestore = sin conexión (o modo avión) | Banner offline; saldos y movimientos de caché con hora; al reconectar se actualiza solo | FR-028/29, SC-003 |
| V13 | Alta latencia | Panel demo → latencia 4000 ms | Skeletons; sin pantallas en blanco | FR-027, SC-007 |
| V14 | Push por segmento | Consola Messaging → topic `segment_student` con `route=/home` | Solo clientes *student* la reciben; al tocar abre inicio | US5-5 |
| V15 | Push en primer plano | Enviar push con la app abierta | Aviso in-app sin interrumpir | US5-3 |
| V16 | Logout | Cerrar sesión | Vuelve a login; no recibe push personales | FR-008 |
| V17 | Aislamiento de datos | Ver casos de [firestore-security.md](./contracts/firestore-security.md) | Accesos ajenos denegados | FR-013 |
| V18 | Accesibilidad | TalkBack + tamaño de fuente máximo en inicio, cuenta y divisas | Todo anunciado y legible | FR-033, SC-010 |
| V19 | E2E automatizado | `flutter test integration_test` | Registro → cuentas → movimientos verde | SC-012 |
| V20 | Observabilidad | Tras V1–V13, revisar Analytics (DebugView) y Crashlytics | Eventos del catálogo sin PII | FR-034/35, SC-011 |
