# Herramientas del banco (`tools/admin`)

Scripts de Node que hacen lo que en producción haría el backend del banco. En el plan
gratuito (Spark) de Firebase no hay Cloud Functions, así que se ejecutan desde una PC con
`firebase-admin`. No pasan por las reglas de Firestore.

## Preparación (una vez)

1. Node 20 o superior.
2. Consola de Firebase → **Configuración del proyecto → Cuentas de servicio → Generar nueva
   clave privada**. Guarda el archivo como `tools/admin/service-account.json`.
   **No se versiona** (`.gitignore`): da acceso total al proyecto.
3. `cd tools/admin && npm install`

## Movimiento con aviso push (V5)

Crea el movimiento y actualiza el saldo en una transacción, y luego envía la push
`type=movement` con `route=/accounts/{id}` a los dispositivos del cliente
(`users/{uid}/devices`).

```bash
node add-movement.js --email ana@bi.test --amount 25 --type credit --desc "Transferencia recibida"
node add-movement.js --uid <uid> --account <accountId> --amount 12.5 --type debit --desc "Cafetería"
```

Sin `--account` se usa la primera cuenta del cliente. Un débito que deja el saldo en negativo
se rechaza.

## Push a todos o a un segmento (V14)

```bash
node send-push.js --topic segment_student --title "Ahorra para tu viaje" \
  --body "Nueva meta de ahorro para estudiantes" --route /offers/student_travel
node send-push.js --topic all --title "Mantenimiento" --body "El domingo de 2 a 4 a. m."
```

Topics: `all`, `segment_student`, `segment_professional`, `segment_entrepreneur`. Sin
`--route` se abre el inicio.

Lo mismo se puede hacer desde **Consola de Firebase → Messaging → Nueva campaña →
Notificaciones**: destino *Tema* y, en *Opciones adicionales → Datos personalizados*, las
claves `type` y `route`.
