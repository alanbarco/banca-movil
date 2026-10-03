# Contract: Rutas de la app (deep links)

Constantes en `lib/core/routing/app_routes.dart`; cada feature declara sus `GoRoute` y `app/`
las compone. `redirect` global según `AuthBloc`.

| Ruta | Pantalla | Feature | Auth | Flag |
|---|---|---|---|---|
| `/splash` | arranque | app | — | — |
| `/login` | inicio de sesión | auth | no | — |
| `/register` | onboarding por pasos | auth | no | — |
| `/forgot-password` | recuperar contraseña | auth | no | — |
| `/home` | inicio personalizado (SDUI) | personalization | sí | — |
| `/accounts/:accountId` | detalle y movimientos | accounts | sí | — |
| `/offers/:offerId` | detalle de oferta | personalization | sí | `offers` |
| `/fx` | tipos de cambio y conversor | fx | sí | `fx_service` |
| `/profile` | perfil, intereses, notificaciones, cerrar sesión | auth | sí | — |
| `/debug/faults` | panel de simulación de fallos | core | sí | `DEMO_TOOLS` + `demo_fault_panel` |

Reglas de `redirect`:

- No autenticado → cualquier ruta protegida redirige a `/login`.
- Autenticado en `/login` o `/register` → siempre `/home` (decisión de producto: el
  cliente entra por el inicio; un deep link de push se abre encima del inicio en US5).
- Ruta con flag apagado → `/home`.
