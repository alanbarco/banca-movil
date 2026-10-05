// Envía una push a un topic (todos o un segmento).
//
//   node send-push.js --topic segment_student --title "Oferta" --body "…" --route /offers/student_travel
//   node send-push.js --topic all --title "Mantenimiento" --body "Domingo 2 a 4 a. m."
//
// Topics: all, segment_student, segment_professional, segment_entrepreneur.
const minimist = require('minimist');
const { admin, required } = require('./firebase');

const args = minimist(process.argv.slice(2), { string: ['topic', 'title', 'body', 'route', 'type'] });

const topics = ['all', 'segment_student', 'segment_professional', 'segment_entrepreneur'];

async function main() {
  const topic = required(args, 'topic');
  if (!topics.includes(topic)) throw new Error(`--topic debe ser uno de: ${topics.join(', ')}`);
  const route = args.route ? String(args.route) : '/home';
  const type = args.type ? String(args.type) : route.startsWith('/offers/') ? 'offer' : 'announcement';

  const id = await admin.messaging().send({
    topic,
    notification: { title: required(args, 'title'), body: required(args, 'body') },
    data: { type, route },
    android: { priority: 'high' },
  });
  console.log(`Push enviada a "${topic}" (${id})`);
}

main().then(
  () => process.exit(0),
  (error) => {
    console.error(error.message ?? error);
    process.exit(1);
  },
);
