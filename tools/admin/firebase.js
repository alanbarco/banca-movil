// Inicializa firebase-admin con la cuenta de servicio local (no versionada).
const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const credentialPath = path.join(__dirname, 'service-account.json');

if (!fs.existsSync(credentialPath)) {
  console.error(
    'Falta tools/admin/service-account.json.\n' +
      'Descárgala en Consola de Firebase → Configuración del proyecto → ' +
      'Cuentas de servicio → Generar nueva clave privada.',
  );
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(credentialPath)) });

/** Falla con un mensaje claro si falta un argumento obligatorio. */
function required(args, name) {
  const value = args[name];
  if (value === undefined || value === true || value === '') {
    console.error(`Falta --${name}`);
    process.exit(1);
  }
  return String(value);
}

module.exports = { admin, required };
