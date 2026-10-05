# Banco Internacional — Plataforma Financiera Digital (Flutter) Constitution

## Core Principles

### I. Clean Architecture Feature-First

La aplicación MUST ser una única app Flutter organizada con Clean Architecture por features,
con límites entre dominios lo bastante estrictos como para extraer cada feature a un paquete
independiente sin reescribirla.

- Estructura de alto nivel dentro de `lib/`:
  - `app/`: composición, DI raíz, routing, tema y arranque. Sin lógica de negocio.
  - `core/`: capacidades transversales (red, almacenamiento, design system, feature flags,
    observabilidad, notificaciones, server-driven UI, conectividad, errores).
  - `features/<feature>/`: una carpeta por dominio (p. ej. `auth`, `accounts`,
    `personalization`, `notifications`, `marketplace`/micro-app externa).
- Cada feature MUST tener las capas `domain` (entidades, contratos de repositorio, casos de
  uso), `data` (modelos, data sources remotos/locales, implementaciones de repositorio) y
  `presentation` (BLoCs, páginas, widgets).
- Regla de dependencia: `presentation → domain ← data`. La capa `domain` MUST ser Dart puro
  (sin imports de Flutter, Firebase, Dio ni paquetes de infraestructura).
- Una feature MUST NOT importar archivos de otra feature. La comunicación entre features
  MUST hacerse vía contratos en `core`, rutas o eventos/streams expuestos por `core`.
- Los errores MUST cruzar capas como tipos `Failure`/`Result` explícitos, no como excepciones
  sin tipar.
- Un ADR MUST documentar la evolución prevista a paquetes por feature (pub workspaces) como
  estrategia de escalamiento hacia equipos independientes.

**Rationale**: Clean Architecture es el patrón que el autor domina. Con 2 días de desarrollo,
una app única con fronteras estrictas entrega la misma modularidad lógica sin el costo de
configurar y mantener un monorepo multi-paquete; la extracción futura queda trazada.

### II. Gestión de Estado con BLoC y Cubit (NON-NEGOTIABLE)

- Todo estado de presentación con lógica MUST gestionarse con `flutter_bloc` (`Bloc` o
  `Cubit`). No se permiten otros gestores de estado (Provider como state manager, Riverpod,
  GetX, MobX).
- Los BLoCs MUST depender únicamente de casos de uso o contratos de `domain`, nunca de data
  sources, SDKs de Firebase ni clientes HTTP.
- Estados y eventos MUST ser inmutables y modelar explícitamente: inicial, cargando, éxito,
  vacío, error y datos en caché/obsoletos cuando aplique (sealed classes o `Equatable`).
- `StatefulWidget` solo se permite para estado efímero de UI (animaciones, controladores de
  texto, foco).
- Cada BLoC MUST tener pruebas con `bloc_test`.

**Rationale**: BLoC es la elección del autor, separa eventos de estados de forma testeable y
encaja con la capa de presentación de Clean Architecture.

### III. Experiencia Dinámica: Feature Flags y Server-Driven UI

- Toda funcionalidad nueva o incompleta MUST estar detrás de un feature flag, consumido a
  través de una abstracción propia en `core` (p. ej. `FeatureFlagService`) para no acoplar
  el código al proveedor.
- Los flags MUST tener valores por defecto locales seguros, de modo que la app funcione si el
  proveedor remoto no responde.
- La personalización (por segmento, perfil, comportamiento o preferencias) MUST resolverse
  con reglas evaluadas desde configuración remota y/o datos del usuario, no con condicionales
  hardcodeados por segmento.
- Las secciones dinámicas (home, banners, ofertas, accesos rápidos) MUST renderizarse con un
  esquema Server-Driven UI (JSON versionado → registro de componentes del design system), de
  modo que nuevas experiencias o contenidos se publiquen sin nueva release de la app.
- Un componente SDUI desconocido o un payload inválido MUST degradarse a un fallback seguro
  (ocultar o mostrar placeholder) y registrarse en observabilidad; nunca romper la pantalla.

**Rationale**: Los requerimientos de la aplicación exigen adaptar la experiencia dinámicamente e incorporar contenidos sin
republicar; los flags además habilitan Trunk Based Development seguro.

### IV. Resiliencia y Degradación Controlada (Offline-First)

- Toda lectura de datos financieros (cuentas, saldos, movimientos) MUST mostrar el último
  dato disponible localmente (persistencia offline de Firestore o caché propia) con indicador
  de antigüedad/origen y refrescarse al recuperar conexión.
- Las llamadas HTTP a servicios externos MUST definir timeout, reintentos con backoff
  exponencial para operaciones idempotentes y caché local de la última respuesta válida;
  MUST NOT reintentarse automáticamente operaciones no idempotentes.
- La app MUST detectar el estado de conectividad y comunicarlo al usuario (banner/estado
  offline), recuperándose automáticamente al restablecerse la conexión.
- La caída de un servicio o dominio (p. ej. la micro-app externa o la personalización) MUST
  aislarse: el resto de la app sigue operativa y el módulo afectado muestra estado degradado.
- Cada pantalla MUST implementar explícitamente estados de carga (skeleton), vacío, error con
  acción de reintento y datos en caché.
- MUST existir un mecanismo demostrable para simular latencia alta y fallos de servicio
  (p. ej. decoradores de repositorio activables por flag o menú de debug) que evidencie
  estos comportamientos en la demo.

**Rationale**: Es un requisito explícito de la aplicación ("manejo de escenarios
degradados") y es crítico en una banca 100 % digital.

### V. Calidad Verificable por Pruebas

- Casos de uso, repositorios y BLoCs MUST tener pruebas unitarias (`test`, `bloc_test`,
  `mocktail`). Cobertura mínima de líneas: 70 % en capas `domain` y `presentation/bloc`
  (objetivo: 80 %).
- Los widgets y páginas clave MUST tener pruebas de widget que cubran al menos los estados
  de carga, éxito y error/offline.
- MUST existir al menos un flujo E2E crítico automatizado con `integration_test`:
  login → consulta de cuentas y saldo → detalle de movimientos.
- Todo bug corregido MUST incluir una prueba que lo reproduzca.
- Las pruebas unitarias y de widget MUST ejecutarse en CI en cada push a `main`; un pipeline
  rojo bloquea nuevos cambios hasta corregirse.

**Rationale**: Los requerimientos de la aplicación exigen pruebas unitarias, de widget y E2E,
y el equipo debe poder ajustar una prueba o diagnosticar una falla con rapidez. El umbral se ajusta a la ventana de 2 días.

### VI. Seguridad y Observabilidad por Diseño

- La sesión MUST gestionarse con Firebase Authentication; cualquier otro dato sensible
  persistido por la app MUST almacenarse con `flutter_secure_storage`, nunca en
  `SharedPreferences` ni en logs.
- El acceso a datos MUST protegerse con Firestore Security Rules versionadas en el repo: un
  cliente solo puede leer/escribir sus propios datos. Las reglas MUST NOT dejarse en modo
  abierto/test.
- La configuración cliente de Firebase (`firebase_options.dart`, `google-services.json`,
  `GoogleService-Info.plist`) no es secreta y MAY versionarse. Claves de cuentas de servicio,
  tokens y credenciales privadas MUST NOT versionarse.
- Los datos sensibles en pantalla (saldos, números de cuenta) MUST poder ocultarse o
  enmascararse.
- La app MUST reportar errores no controlados, crashes y eventos de UX clave (p. ej. funnel
  de onboarding, errores de carga) a través de una abstracción propia en `core`
  (p. ej. `ObservabilityService`), desacoplada del proveedor.
- Los logs MUST ser estructurados, con nivel y contexto (feature, pantalla), y MUST NOT
  contener PII.
- La UI MUST cumplir accesibilidad básica: etiquetas `Semantics`, contraste suficiente,
  soporte de escalado de texto y áreas táctiles ≥ 48 dp.

**Rationale**: Seguridad, observabilidad y accesibilidad son requerimientos
explícitos y obligatorios en un contexto bancario.

### VII. Costo Cero con Integración Real

- Ningún servicio, librería o herramienta usada MUST generar costo ni requerir tarjeta de
  crédito. Solo se permiten software open source y planes gratuitos sin tarjeta (Firebase
  plan Spark, GitHub Actions, APIs públicas gratuitas sin clave de pago).
- Quedan prohibidos servicios que exijan plan de pago para funcionar (p. ej. Firebase Cloud
  Functions, que requiere plan Blaze).
- La solución MUST interactuar con servicios reales (Firebase y al menos un servicio externo
  HTTP), no solo con mocks o JSON estáticos embebidos. Los mocks se permiten únicamente en
  pruebas y como fallback documentado.
- La configuración de servicios MUST versionarse como código y aplicarse con comandos
  documentados: Firestore Security Rules e índices (Firebase CLI), plantilla de Remote
  Config y datos semilla (script o pasos reproducibles en el README).

**Rationale**: Los requerimientos de la aplicación fijan costo cero e integración con
servicios reales (una solución solo con datos simulados no es válida).

### VIII. Decisiones Documentadas y Uso Transparente de IA

- Toda decisión arquitectónica relevante MUST registrarse como ADR en `docs/adr/` con:
  problema, alternativas evaluadas, opción seleccionada, trade-offs e impacto a largo plazo.
- La documentación MUST incluir diagramas (componentes, flujos, dependencias) en formato
  versionable (Mermaid), supuestos, riesgos técnicos y estrategia de escalamiento.
- MUST existir documentación de despliegue y operación: monitoreo en producción, detección de
  problemas operativos y de UX, y comportamiento ante conectividad degradada.
- El uso de herramientas de IA MUST documentarse en `docs/ai-usage.md`: herramientas, para
  qué se usaron, ejemplos y su impacto en productividad, calidad, documentación y pruebas.
- El README MUST permitir configurar, ejecutar, probar y colaborar de forma reproducible.

**Rationale**: La documentación y el uso de IA son parte de los requerimientos de la aplicación.

## Restricciones Tecnológicas y de Costo

- **Framework**: Flutter (canal estable) y Dart 3.x. Plataforma principal: Android
  (iOS compatible sin ser requisito de la demo).
- **Estado**: `flutter_bloc` (ver Principio II).
- **Estructura**: app única feature-first (ver Principio I).
- **Navegación**: `go_router`, con rutas declaradas por cada feature y compuestas en `app/`.
- **Inyección de dependencias**: `get_it` configurado en `app/`; cada feature expone su
  función de registro.
- **Backend (Firebase, plan Spark)**:
  - Autenticación: Firebase Authentication (email/contraseña).
  - Datos: Cloud Firestore con persistencia offline habilitada.
  - Feature flags y SDUI: Firebase Remote Config.
  - Notificaciones push: Firebase Cloud Messaging; envío desde la consola de Firebase o un
    script local, nunca desde Cloud Functions.
  - Observabilidad: Firebase Crashlytics y Analytics.
- **Servicio/micro-app externa**: API pública gratuita vía HTTP (`dio` o `http`) y/o
  aplicación web embebida en WebView alojada gratis.
- **Persistencia local**: persistencia offline de Firestore + almacenamiento local ligero
  (p. ej. `shared_preferences`/`hive`) para cachés no sensibles + `flutter_secure_storage`.
- **CI/CD**: GitHub Actions.
- **Alternativas descartadas** (a documentar en ADR): Supabase y backend propio
  (Dart Shelf/Node) por el costo de tiempo de montar y operar frente a la ventana de 2 días.
- Toda dependencia nueva MUST justificarse (propósito, licencia, mantenimiento activo) y no
  romper el Principio VII.

## Flujo de Desarrollo y Quality Gates

- **Trunk Based Development**: `main` es la única rama de larga vida. Se trabaja con commits
  directos pequeños o ramas de vida corta (< 1 día) integradas rápidamente. El trabajo
  incompleto se integra oculto tras feature flags (Principio III).
- **Commits**: frecuentes, atómicos y con Conventional Commits (`feat:`, `fix:`, `test:`,
  `docs:`, `refactor:`, `chore:`, `ci:`), en un único idioma de forma consistente.
- **Spec Kit**: se permite una única spec para el MVP completo; cada paso del flujo
  (specify, clarify, plan, tasks) MUST quedar commiteado.
- **Quality gates en CI** (cada push a `main`), todos MUST pasar:
  1. `dart format --set-exit-if-changed`
  2. `flutter analyze` sin warnings (`flutter_lints` o `very_good_analysis`)
  3. Pruebas unitarias y de widget con umbral de cobertura (Principio V)
  4. Build de la app Android (debug)
- **E2E**: se ejecuta localmente en emulador/dispositivo antes de cada entrega; su ejecución
  en CI es opcional.
- **Definición de Hecho** de una funcionalidad: código conforme a Principios I–II, pruebas
  verdes, estados degradados implementados, ADR si hubo decisión relevante y documentación
  actualizada.
- La generación de código (`build_runner`, `freezed`, `json_serializable`), si se usa, MUST
  ser reproducible con un comando documentado.

## Governance

- Esta constitución prevalece sobre cualquier otra práctica o preferencia del proyecto.
  Los artefactos de Spec Kit (`spec`, `plan`, `tasks`) MUST verificar su cumplimiento en la
  sección "Constitution Check" del plan.
- Cualquier violación MUST justificarse explícitamente en la tabla de complejidad del plan,
  indicando por qué la alternativa conforme no es viable.
- **Enmiendas**: se realizan mediante `/speckit-constitution`, documentando el motivo y,
  si aplica, un ADR asociado y un plan de migración del código existente.
- **Versionado semántico** de la constitución:
  - MAJOR: eliminación o redefinición incompatible de principios o reglas de gobierno.
  - MINOR: nuevo principio/sección o ampliación material de una regla.
  - PATCH: aclaraciones, redacción o correcciones no semánticas.
- **Revisión de cumplimiento**: antes de cada entrega/demo se revisa el cumplimiento de los
  Principios I–VIII y de los quality gates; los hallazgos se corrigen o se registran como
  riesgos conocidos en la documentación.

**Version**: 2.0.0 | **Ratified**: 2026-10-03 | **Last Amended**: 2026-10-03
