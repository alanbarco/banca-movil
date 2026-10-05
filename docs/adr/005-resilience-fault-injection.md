# ADR-005: Resiliencia offline-first y simulador de fallos

- **Estado**: aceptada · 2026-10-03 (ajustada 2026-10-04)
- **Fuente**: [research.md R6](../../specs/001-digital-banking-mvp/research.md)

## Problema

Los requerimientos de la aplicación piden **demostrar** el comportamiento ante conectividad limitada, alta latencia e
indisponibilidad parcial, con estados de carga, reintentos, caché y recuperación. Con modo
avión se cae todo a la vez: no permite mostrar que un servicio falla y el resto sigue.

## Alternativas evaluadas

| Opción | En contra |
|---|---|
| Modo avión manual | No aísla un servicio; no permite fijar una latencia |
| Proxy de red (Charles, mitmproxy) | Complejo de montar para la demo; no cubre los SDK de Firebase con facilidad |
| UI que solo "aparenta" fallar | No ejercita el código real de recuperación |
| **Inyección de fallos en la puerta de entrada de cada servicio** | — |

## Decisión

**Resiliencia (siempre activa):**

- Cuentas y movimientos: persistencia offline de Firestore; `isFromCache` marca los datos como
  desactualizados. `StaleDataGate` solo muestra el aviso si no hay red o pasan 5 s sin
  confirmación del servidor (evita parpadeos). La hora de la última sincronización se guarda
  localmente.
- Caché vacía y servidor sin responder: error con "Reintentar", sin dejar de escuchar; los
  datos aparecen solos cuando vuelve el servidor.
- Divisas: reintentos con backoff y caché propia ([ADR-004](004-fx-external-service.md)).
- Inicio: si Remote Config falla, se mantiene el último layout o los valores por defecto
  locales.
- Banner global de conectividad (`ConnectivityCubit`).

**Simulador (solo builds con `DEMO_TOOLS=true` + flag remoto `demo_fault_panel`):**

- Panel `/debug/faults` con modos por servicio: normal, sin red, lento (0,5–8 s), error.
- Solo se inyecta el fallo en la entrada (`FaultRunner` para Firebase, `FaultInterceptor`
  para dio); **todo lo demás es el código real**: reintentos, cachés, estados y eventos.
- Firestore "sin red" y "error" usan `disableNetwork()` real. "Error" imita lo que hace el SDK
  ante un `unavailable`: responder desde la caché y reintentar solo.

## Trade-offs

- El simulador vive en el binario de demo. Doble candado: compilación (`DEMO_TOOLS`) y flag
  remoto, además del guard de rutas. En release sin `DEMO_TOOLS`, `NoFaults` deja el código
  sin efecto.
- Mostrar caché es correcto para **consultar**, no para **operar**: no hay acciones de dinero
  en el MVP y cualquier operación se validaría en servidor.
- No hay caducidad de caché por antigüedad (se muestra la hora, sin límite).

## Impacto a largo plazo

Los mismos puntos de inyección sirven para pruebas de caos automatizadas en CI. La siguiente
mejora natural es una política de caducidad por tipo de dato (saldo vs. tasas).
