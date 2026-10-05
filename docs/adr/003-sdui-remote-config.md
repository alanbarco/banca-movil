# ADR-003: Inicio Server-Driven UI sobre Remote Config

- **Estado**: aceptada · 2026-10-03
- **Fuente**: [research.md R4](../../specs/001-digital-banking-mvp/research.md) ·
  [remote-config.md](../../specs/001-digital-banking-mvp/contracts/remote-config.md)

## Problema

Los requerimientos de la aplicación piden que la experiencia se adapte al perfil y preferencias del cliente y que se puedan
**incorporar contenidos y componentes sin publicar una versión nueva**. Además, el inicio
debe mostrar piezas de varias features (cuentas, ofertas, accesos) sin acoplarlas entre sí.

## Alternativas evaluadas

| Opción | A favor | En contra |
|---|---|---|
| **Remote Config con JSON tipado** | Gratis, caché persistente (funciona offline), propagación en segundos, consola amigable | Límite de tamaño por parámetro; sin historial de contenido por cliente |
| Layouts en Firestore | También en tiempo real | Mezcla contenido con datos transaccionales; más reglas |
| Condiciones de Remote Config por propiedad de Analytics | Menos JSON | Propagación impredecible (horas) para la demo |
| Pantallas fijas con `if (segmento)` | Simple | Cada cambio requiere publicar; no escala |

## Decisión

- Parámetro `home_layout`: un layout por segmento, con **secciones tipadas** (`banner`,
  `offer_carousel`, `quick_actions`, `tip`, `accounts_summary`), orden, flag e intereses.
- `ResolveHomeLayout` (caso de uso de `domain`) elige el layout del segmento, quita secciones
  con flag apagado o sin coincidencia de intereses y ordena (orden del banco y, a igual
  orden, primero lo que coincide con los intereses).
- `SectionRegistry` (`core/sdui`) traduce cada tipo a un widget. **Cada feature registra sus
  tipos** desde su módulo, así el inicio compone piezas de varias features sin imports
  cruzados.
- Tipos desconocidos o JSON inválido **se omiten** y se reporta `sdui_section_skipped`.
- Las rutas que manda el servidor se validan contra `AppRoutes` (nada de URLs arbitrarias).
- `feature_flags` (habilitado + segmentos) controla pestañas, rutas e ítems, incluso por
  deep link. Remote Config en tiempo real (`onConfigUpdated`) aplica los cambios sin
  reiniciar.

## Trade-offs

- El servidor solo combina **componentes que la app ya conoce**: un tipo nuevo de sección
  requiere publicar. Es el límite habitual de SDUI y lo que lo mantiene seguro y testeable.
- La segmentación se evalúa en el cliente: es rápida y predecible, pero todo cliente
  descarga el JSON de todos los segmentos (contenido no sensible).
- Hay un riesgo de desincronización entre la consola y `firebase/remoteconfig.template.json`
  (ver [operations.md](../operations.md)).

## Impacto a largo plazo

El mismo contrato de secciones puede servirlo un backend de contenidos (CMS o motor de
personalización) cuando el tamaño o la lógica superen a Remote Config: la app solo cambia
de datasource. Nuevos dominios suman secciones registrándose en `SectionRegistry`.
