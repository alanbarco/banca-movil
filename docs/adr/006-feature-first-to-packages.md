# ADR-006: App única feature-first, con camino a paquetes por dominio

- **Estado**: aceptada · 2026-10-03
- **Fuente**: [research.md R9](../../specs/001-digital-banking-mvp/research.md) ·
  [constitución v2.0.0](../../.specify/memory/constitution.md)

## Problema

Los requerimientos de la aplicación piden que la solución pueda evolucionar hacia **múltiples dominios administrados por
equipos independientes**. A la vez, el MVP debe construirse en 2 días por una persona.

## Alternativas evaluadas

| Opción | A favor | En contra |
|---|---|---|
| Monorepo multi-paquete desde el día 1 (melos / pub workspaces) | Fronteras forzadas por el compilador | Configuración, versionado y CI multiplicados para un MVP de una persona |
| App sin capas | Rápido al inicio | Imposible de repartir entre equipos |
| **App única `lib/{app,core,features}` con fronteras por convención y módulos** | Rápida de construir, fácil de extraer después | Las fronteras dependen de disciplina y revisión |

## Decisión

- `features/<dominio>/{domain,data,presentation}`; `domain` es Dart puro.
- **Sin imports entre features.** Lo compartido vive en `core` como contratos:
  `CurrentUserProfile`, `SessionEvents`, `SectionRegistry`, `NotificationsToggle`,
  `PendingRouteStore`.
- Cada feature expone un `FeatureModule`: registra sus dependencias (`get_it`), sus rutas y
  sus secciones SDUI, y puede envolver el shell o reaccionar al arranque. `app/` solo compone
  la lista de módulos; quitar una feature es quitar una línea en `di.dart`.
- Casos de uso **solo cuando hay lógica** (`ResolveHomeLayout`, `RegisterCustomer`,
  `ConvertCurrency`…); si solo reenvían, el BLoC usa la interfaz del repositorio.
- `flutter_bloc` + `equatable` + sealed classes, sin generación de código.

## Trade-offs

- Las fronteras no las hace cumplir el compilador. Se sostienen con revisión y con la regla
  de no importar entre features.
- Sin codegen hay algo más de código manual (props, copyWith), a cambio de builds rápidos y
  menos herramientas.

## Impacto a largo plazo

Cada `features/<dominio>` ya tiene la forma de un paquete: su módulo es la API pública y
solo depende de `core`. La evolución es mover `core` a `packages/core` y cada dominio a
`packages/feature_<dominio>` con pub workspaces, sin reescribir código, y asignar cada
paquete a un equipo con su propio CODEOWNERS y pipeline.
