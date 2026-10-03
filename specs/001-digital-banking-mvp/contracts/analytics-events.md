# Contract: Eventos de observabilidad

Emitidos vía `ObservabilityService` (core). Implementación: Firebase Analytics (eventos) y
Crashlytics (errores no fatales y crashes). **Ningún parámetro puede contener PII**: nada de
correos, nombres, saldos, montos ni números de cuenta (FR-034).

| Evento | Parámetros | Origen / requisito |
|---|---|---|
| `onboarding_step_viewed` | `step` | FR-035, US1-8 |
| `onboarding_abandoned` | `last_step` | FR-035 |
| `onboarding_completed` | `segment` | FR-035 |
| `login_success` | — | FR-035 |
| `login_failure` | `reason` (`invalid_credentials`, `network`, `other`) | FR-035 |
| `session_timeout` | — | FR-007 |
| `data_load_error` | `feature`, `reason` | FR-035 |
| `stale_data_shown` | `feature` | FR-028 |
| `sdui_section_skipped` | `section_type`, `reason` | FR-016 |
| `feature_flag_evaluated` | `flag`, `enabled` | trazabilidad de personalización |
| `fx_service_failure` | `reason` | FR-022 |
| `push_opened` | `type` | FR-026 |
| `connectivity_changed` | `online` | FR-029 |

User properties: `segment` (no es PII).

Crashlytics: errores no controlados (`FlutterError.onError`,
`PlatformDispatcher.instance.onError`) y `recordError` no fatal para `Failure.unknown`/`server`.
