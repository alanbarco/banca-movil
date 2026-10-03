<!--
Sync Impact Report
==================
Version change: (template sin versionar) → 1.0.0
Bump rationale: Ratificación inicial; se reemplazan todos los placeholders de la plantilla.

Principios (placeholder → título):
  - [PRINCIPLE_1_NAME] → I. Clean Architecture Modular por Feature
  - [PRINCIPLE_2_NAME] → II. Gestión de Estado con BLoC (NON-NEGOTIABLE)
  - [PRINCIPLE_3_NAME] → III. Experiencia Dinámica: Feature Flags y Server-Driven UI
  - [PRINCIPLE_4_NAME] → IV. Resiliencia y Degradación Controlada (Offline-First)
  - [PRINCIPLE_5_NAME] → V. Calidad Verificable por Pruebas
Principios añadidos (más allá de los 5 de la plantilla):
  - VI. Seguridad y Observabilidad por Diseño
  - VII. Costo Cero con Integración Real
  - VIII. Decisiones Documentadas y Uso Transparente de IA
Secciones añadidas:
  - Restricciones Tecnológicas y de Costo  ([SECTION_2_NAME])
  - Flujo de Desarrollo y Quality Gates    ([SECTION_3_NAME])
Secciones eliminadas: ninguna

Plantillas dependientes (leen la constitución en tiempo de ejecución; no se modifican aquí):
  - .specify/templates/plan-template.md     ⚠ revisar que el "Constitution Check" cubra los principios I–VIII
  - .specify/templates/spec-template.md     ✅ sin cambios requeridos
  - .specify/templates/tasks-template.md    ⚠ las tareas deben incluir pruebas unit/widget/E2E (Principio V)

TODOs diferidos: ninguno
-->

# Banco Internacional — Plataforma Financiera Digital (Flutter) Constitution

## Core Principles

### I. Clean Architecture Modular por Feature

La aplicación MUST combinar Clean Architecture con modularización *feature-first* en un
monorepo de paquetes Dart/Flutter, de modo que cada dominio funcional pueda ser propiedad de
un equipo independiente.

- Estructura de alto nivel:
  - `apps/<app_shell>`: composición, DI raíz, routing y arranque. Sin lógica de negocio.
  - `packages/core/*`: capacidades transversales (red, almacenamiento, design system,
    feature flags, observabilidad, notificaciones, server-driven UI).
  - `packages/features/*`: un paquete por dominio (p. ej. `auth`, `accounts`,
    `personalization`, `notifications`, `marketplace`/micro-app externa).
- Cada feature MUST tener las capas `domain` (entidades, contratos de repositorio, casos de
  uso), `data` (DTOs, data sources remotos/locales, implementaciones de repositorio) y
  `presentation` (BLoCs, páginas, widgets).
- Regla de dependencia: `presentation → domain ← data`. La capa `domain` MUST ser Dart puro
  (sin imports de Flutter, Dio, Firebase ni paquetes de infraestructura).
- Una feature MUST NOT importar otra feature directamente. La comunicación entre features
  MUST hacerse vía contratos en `core`, navegación declarativa (rutas) o eventos de dominio.
- Los errores MUST cruzar capas como tipos `Failure`/`Result` explícitos, no como excepciones
  sin tipar.

**Rationale**: Clean Architecture es el patrón que el equipo domina; la modularización por
paquetes añade el aislamiento que exige el reto (múltiples dominios, equipos independientes,
escalabilidad) sin introducir la complejidad de micro-frontends nativos.

### II. Gestión de Estado con BLoC (NON-NEGOTIABLE)

- Todo estado de presentación con lógica MUST gestionarse con `flutter_bloc` (`Bloc` o
  `Cubit`). No se permiten otros gestores de estado (Provider como state manager, Riverpod,
  GetX, MobX).
- Los BLoCs MUST depender únicamente de casos de uso o contratos de `domain`, nunca de data
  sources ni clientes HTTP.
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

**Rationale**: El reto exige adaptar la experiencia dinámicamente e incorporar contenidos sin
republicar; los flags además habilitan Trunk Based Development seguro.

### IV. Resiliencia y Degradación Controlada (Offline-First)

- Toda lectura de datos financieros (cuentas, saldos, movimientos) MUST seguir una estrategia
  *cache-then-network*: mostrar el último dato persistido localmente con indicador de
  antigüedad y refrescar en segundo plano.
- Las llamadas de red MUST definir timeout, reintentos con backoff exponencial + jitter para
  operaciones idempotentes, y MUST NOT reintentar automáticamente operaciones no idempotentes.
- La app MUST detectar el estado de conectividad y comunicarlo al usuario (banner/estado
  offline), recuperándose automáticamente al restablecerse la conexión.
- La caída de un servicio o dominio (p. ej. la micro-app externa o la personalización) MUST
  aislarse: el resto de la app sigue operativa y el módulo afectado muestra estado degradado.
- Cada pantalla MUST implementar explícitamente estados de carga (skeleton), vacío, error con
  acción de reintento y datos en caché.
- Debe existir un mecanismo demostrable (p. ej. interceptor de simulación de latencia/fallo
  activable por flag en entornos no productivos) para evidenciar estos comportamientos en la
  demo.

**Rationale**: Es un requisito explícito de alcance y de evaluación ("manejo de escenarios
degradados") y es crítico en una banca 100 % digital.

### V. Calidad Verificable por Pruebas

- Casos de uso, repositorios y BLoCs MUST tener pruebas unitarias (`test`, `bloc_test`,
  `mocktail`). Cobertura mínima de líneas: 80 % en capas `domain` y `presentation/bloc`.
- Los widgets y páginas clave MUST tener pruebas de widget que cubran los estados de carga,
  éxito, vacío, error y offline.
- MUST existir al menos un flujo E2E crítico automatizado (`integration_test` o Patrol):
  onboarding/login → consulta de cuentas y saldo → detalle de movimientos.
- Todo bug corregido MUST incluir una prueba que lo reproduzca.
- Las pruebas MUST ejecutarse en CI en cada push a `main`; un pipeline rojo bloquea nuevos
  cambios hasta corregirse.

**Rationale**: El reto exige pruebas unitarias, de widget y E2E, y en la demo se puede pedir
ajustar una prueba o diagnosticar una falla.

### VI. Seguridad y Observabilidad por Diseño

- Tokens y datos sensibles MUST almacenarse con `flutter_secure_storage`; nunca en
  `SharedPreferences` ni en logs.
- Secretos, API keys privadas y cuentas de servicio MUST NOT versionarse; se inyectan con
  `--dart-define`/archivos de entorno ignorados por git, con un `.example` documentado.
- Todo tráfico MUST ser HTTPS; los datos sensibles en pantalla (saldos, números de cuenta)
  MUST poder ocultarse/enmascararse.
- La app MUST reportar errores no controlados, crashes, métricas de rendimiento (arranque,
  latencia de red, tiempos de pantalla) y eventos de UX clave a través de una abstracción
  propia en `core` (p. ej. `ObservabilityService`), desacoplada del proveedor.
- Los logs MUST ser estructurados, con nivel y contexto (feature, pantalla, correlation id),
  y MUST NOT contener PII.
- La UI MUST cumplir accesibilidad básica: etiquetas `Semantics`, contraste suficiente,
  soporte de escalado de texto y áreas táctiles ≥ 48 dp.

**Rationale**: Seguridad, observabilidad y accesibilidad son criterios de evaluación
explícitos y obligatorios en un contexto bancario.

### VII. Costo Cero con Integración Real

- Ningún servicio, librería o herramienta usada MUST generar costo ni requerir tarjeta de
  crédito. Solo se permiten software open source y planes gratuitos sin tarjeta (p. ej.
  Firebase plan Spark, GitHub Actions en repositorio público, APIs públicas gratuitas).
- Quedan prohibidos servicios que exijan plan de pago para funcionar (p. ej. Firebase Cloud
  Functions, que requiere plan Blaze).
- Aun siendo gratuita, la solución MUST interactuar con servicios reales (backend local o
  servicios gratuitos), no solo con mocks o JSON estáticos embebidos. Los mocks se permiten
  únicamente en pruebas y como fallback documentado.
- Cualquier backend propio (BFF, servidor de SDUI/flags, emisor de push) MUST poder
  levantarse localmente con un solo comando documentado (p. ej. `docker compose up` o
  `dart run`).

**Rationale**: Restricción explícita del autor (prueba técnica sin costos) y del evaluador
(las soluciones solo con datos simulados no puntúan).

### VIII. Decisiones Documentadas y Uso Transparente de IA

- Toda decisión arquitectónica relevante MUST registrarse como ADR en `docs/adr/` con:
  problema, alternativas evaluadas, opción seleccionada, trade-offs e impacto a largo plazo.
- La documentación MUST incluir diagramas (componentes, flujos, dependencias) en formato
  versionable (Mermaid o PlantUML), supuestos, riesgos técnicos y estrategia de escalamiento.
- MUST existir documentación de despliegue y operación: monitoreo en producción, detección de
  problemas operativos y de UX, y comportamiento ante conectividad degradada.
- El uso de herramientas de IA MUST documentarse en `docs/ai-usage.md`: herramientas, para
  qué se usaron, ejemplos y su impacto en productividad, calidad, documentación y pruebas.
- El README MUST permitir configurar, ejecutar, probar y colaborar de forma reproducible.

**Rationale**: La documentación y el uso de IA son entregables y criterios evaluados.

## Restricciones Tecnológicas y de Costo

- **Framework**: Flutter (canal estable) y Dart 3.x. Plataformas objetivo: Android e iOS.
- **Estado**: `flutter_bloc` (ver Principio II).
- **Monorepo**: Dart pub workspaces y/o Melos para gestionar paquetes `core` y `features`.
- **Navegación**: router declarativo (p. ej. `go_router`) con rutas registradas por cada
  feature.
- **Inyección de dependencias**: contenedor único configurado en el app shell (p. ej.
  `get_it`); las features exponen su propio módulo de registro.
- **Red**: cliente HTTP con interceptores (p. ej. `dio`) para auth, reintentos, logging y
  simulación de fallos.
- **Persistencia local**: base local para caché (p. ej. Drift/Hive/Isar) +
  `flutter_secure_storage` para credenciales.
- **Servicios gratuitos de referencia** (decisión final por ADR en `/speckit-plan`):
  - Autenticación: Firebase Authentication (Spark) o backend local con JWT.
  - Feature flags / configuración remota: Firebase Remote Config (Spark).
  - Notificaciones push: Firebase Cloud Messaging; el envío MUST hacerse desde un backend
    local o script, no desde Cloud Functions.
  - Observabilidad: Firebase Crashlytics, Performance Monitoring y Analytics (Spark).
  - Micro-app/servicio externo: aplicación web embebida (WebView con puente JS) alojada
    gratis (GitHub Pages/Firebase Hosting) y/o API pública gratuita sin tarjeta.
  - CI/CD: GitHub Actions.
- Toda dependencia nueva MUST justificarse (propósito, licencia, mantenimiento activo) y no
  romper el Principio VII.

## Flujo de Desarrollo y Quality Gates

- **Trunk Based Development**: `main` es la única rama de larga vida. Se trabaja con commits
  directos pequeños o ramas de vida corta (< 1 día) integradas rápidamente. El trabajo
  incompleto se integra oculto tras feature flags (Principio III).
- **Commits**: frecuentes, atómicos y con Conventional Commits (`feat:`, `fix:`, `test:`,
  `docs:`, `refactor:`, `chore:`, `ci:`), en español o inglés de forma consistente.
- **Quality gates en CI** (cada push a `main`), todos MUST pasar:
  1. `dart format --set-exit-if-changed`
  2. `flutter analyze` sin warnings (lints estrictos, p. ej. `very_good_analysis` o
     `flutter_lints` endurecido)
  3. Pruebas unitarias y de widget con umbral de cobertura (Principio V)
  4. Build de la app (al menos Android debug/profile)
  5. E2E crítico (en CI con emulador cuando sea viable; si no, documentado y ejecutado antes
     de cada entrega)
- **Definición de Hecho** de una feature: spec + plan aprobados, código bajo flag, pruebas
  verdes, ADR si hubo decisión relevante, documentación/README actualizados y estados
  degradados implementados.
- La generación de código (`build_runner`, `freezed`, `json_serializable`) MUST ser
  reproducible con un comando documentado.

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

**Version**: 1.0.0 | **Ratified**: 2026-10-03 | **Last Amended**: 2026-10-03
