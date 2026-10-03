# Contract: Notificaciones push (FCM)

## Destinos

| Destino | Mecanismo | Suscripción |
|---|---|---|
| Todos | topic `all` | al iniciar sesión con permiso concedido |
| Segmento | topic `segment_<student\|professional\|entrepreneur>` | al iniciar sesión y al cambiar de segmento (des-suscribe el anterior) |
| Cliente | tokens en `users/{uid}/devices/{token}` | al iniciar sesión / `onTokenRefresh` |

Al cerrar sesión: unsubscribe de topics, borrar `devices/{token}` y `deleteToken()` (FR-008).

## Payload

```json
{
  "notification": { "title": "Nuevo movimiento", "body": "Recibiste $40.00" },
  "data": {
    "type": "movement | offer | announcement",
    "route": "/accounts/{accountId} | /offers/{offerId} | /home"
  }
}
```

- `route` debe coincidir con una ruta de [ui-routes.md](./ui-routes.md); si no, se abre `/home`.
- Si la sesión no está activa, la ruta se guarda y se navega tras autenticarse (FR-026).

## Comportamiento por estado de la app

| Estado | Comportamiento |
|---|---|
| Cerrada (terminated) | notificación del sistema; `getInitialMessage()` → navegar a `route` |
| Segundo plano | notificación del sistema; `onMessageOpenedApp` → navegar a `route` |
| Primer plano | `onMessage` → aviso in-app (banner) con acción "Ver" (FR-025) |

## Envío (herramientas del banco)

- **Consola de Firebase → Messaging**: campañas a topics `all` / `segment_*`.
- **`tools/admin`** (Node + `firebase-admin`, credenciales locales no versionadas):
  - `add-movement --uid --account --amount --type --desc`: transacción que crea el
    movimiento, actualiza el saldo y envía push `type=movement` a los tokens del cliente.
  - `send-push --topic <topic> --title --body --route`.
