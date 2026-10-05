// Simula el core bancario: registra un movimiento, actualiza el saldo y avisa
// al cliente por push (contracts/push-notifications.md).
//
//   node add-movement.js --email ana@bi.test --amount 25 --type credit --desc "Pago"
//   node add-movement.js --uid <uid> --account <id> --amount 10.5 --type debit --desc "Café"
//
// Sin --account usa la primera cuenta del cliente.
const minimist = require('minimist');
const { admin, required } = require('./firebase');

const args = minimist(process.argv.slice(2), { string: ['uid', 'account', 'email', 'desc'] });

async function resolveUid() {
  if (args.uid) return String(args.uid);
  const email = required(args, 'email');
  return (await admin.auth().getUserByEmail(email)).uid;
}

async function resolveAccount(db, uid) {
  if (args.account) return String(args.account);
  const accounts = await db.collection(`users/${uid}/accounts`).limit(1).get();
  if (accounts.empty) throw new Error(`El cliente ${uid} no tiene cuentas`);
  return accounts.docs[0].id;
}

/** Mismo formato que la app (MoneyText, es_EC): "$1.300,00". */
function money(cents) {
  const amount = (cents / 100).toLocaleString('es-EC', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `$${amount}`;
}

async function main() {
  const amountCents = Math.round(Number(required(args, 'amount')) * 100);
  const type = required(args, 'type');
  const description = required(args, 'desc');
  if (!Number.isInteger(amountCents) || amountCents <= 0) throw new Error('--amount debe ser > 0');
  if (!['credit', 'debit'].includes(type)) throw new Error('--type debe ser credit o debit');
  if (description.length > 60) throw new Error('--desc admite hasta 60 caracteres');

  const db = admin.firestore();
  const uid = await resolveUid();
  const accountId = await resolveAccount(db, uid);
  const accountRef = db.doc(`users/${uid}/accounts/${accountId}`);

  // Transacción: el saldo y el movimiento cambian juntos o no cambian.
  const balanceAfterCents = await db.runTransaction(async (tx) => {
    const account = await tx.get(accountRef);
    if (!account.exists) throw new Error(`No existe la cuenta ${accountId}`);
    const balance = account.get('balanceCents');
    const next = type === 'credit' ? balance + amountCents : balance - amountCents;
    if (next < 0) throw new Error(`Saldo insuficiente: ${money(balance)}`);

    const now = admin.firestore.Timestamp.now();
    tx.create(accountRef.collection('movements').doc(), {
      date: now,
      description,
      amountCents,
      type,
      balanceAfterCents: next,
    });
    tx.update(accountRef, { balanceCents: next, updatedAt: now });
    return next;
  });
  console.log(`Movimiento registrado. Saldo nuevo: ${money(balanceAfterCents)}`);

  await notify(db, uid, accountId, {
    title: type === 'credit' ? 'Recibiste dinero' : 'Nuevo cargo en tu cuenta',
    body: `${type === 'credit' ? '+' : '−'}${money(amountCents)} · ${description}`,
  });
}

/** Envía a todos los dispositivos del cliente y borra los tokens vencidos. */
async function notify(db, uid, accountId, notification) {
  const devices = await db.collection(`users/${uid}/devices`).get();
  if (devices.empty) {
    console.log('El cliente no tiene dispositivos con push activadas: no se envía aviso.');
    return;
  }
  const tokens = devices.docs.map((doc) => doc.id);
  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification,
    data: { type: 'movement', route: `/accounts/${accountId}` },
    android: { priority: 'high' },
  });

  const stale = response.responses
    .map((r, i) => (r.error?.code === 'messaging/registration-token-not-registered' ? tokens[i] : null))
    .filter(Boolean);
  await Promise.all(stale.map((token) => db.doc(`users/${uid}/devices/${token}`).delete()));
  console.log(`Push enviada: ${response.successCount}/${tokens.length} dispositivos` +
    (stale.length ? ` (${stale.length} tokens vencidos borrados)` : ''));
}

main().then(
  () => process.exit(0),
  (error) => {
    console.error(error.message ?? error);
    process.exit(1);
  },
);
