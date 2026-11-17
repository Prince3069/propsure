// A tiny in-memory stand-in for lib/admin.js so the real business logic in
// payments/listings/founder can be exercised without a Firebase project.
// Transactions are serialised, which is how Firestore behaves under contention.
const store = new Map();
const SERVER_TS = { __sentinel: 'serverTimestamp' };
class Ts { constructor(ms) { this.ms = ms; } toMillis() { return this.ms; } toDate() { return new Date(this.ms); } }
const Timestamp = { fromMillis: (ms) => new Ts(ms), now: () => new Ts(Date.now()) };
const FieldValue = {
  serverTimestamp: () => SERVER_TS,
  arrayUnion: (...v) => ({ __union: v }),
  arrayRemove: (...v) => ({ __remove: v }),
  increment: (n) => ({ __inc: n }),
};
function resolve(prev, patch) {
  const out = { ...(prev || {}) };
  for (const [k, v] of Object.entries(patch)) {
    if (v === SERVER_TS) out[k] = new Ts(Date.now());
    else if (v && v.__union) out[k] = [...(out[k] || []), ...v.__union];
    else if (v && v.__inc != null) out[k] = (out[k] || 0) + v.__inc;
    else if (k.includes('.')) { const [a, b] = k.split('.'); out[a] = { ...(out[a] || {}), [b]: v }; }
    else out[k] = v;
  }
  return out;
}
class Doc {
  constructor(path) { this.path = path; this.id = path.split('/').pop(); }
  collection(name) { return new Col(`${this.path}/${name}`); }
  async get() { const d = store.get(this.path); return { exists: d !== undefined, id: this.id, ref: this, data: () => (d ? { ...d } : undefined) }; }
  async set(v, opts) { store.set(this.path, opts && opts.merge ? resolve(store.get(this.path), v) : resolve({}, v)); }
  async update(v) { if (!store.has(this.path)) throw new Error('NOT_FOUND ' + this.path); store.set(this.path, resolve(store.get(this.path), v)); }
  async create(v) { if (store.has(this.path)) { const e = new Error('already exists'); e.code = 6; throw e; } store.set(this.path, resolve({}, v)); }
}
class Col { constructor(path) { this.path = path; } doc(id) { return new Doc(`${this.path}/${id || 'auto' + Math.random().toString(36).slice(2)}`); } }
let queue = Promise.resolve();
const db = {
  collection: (n) => new Col(n),
  runTransaction(cb) {
    const run = async () => {
      const writes = [];
      const t = {
        get: async (ref) => ref.get(),
        update: (ref, v) => writes.push(() => ref.update(v)),
        set: (ref, v, o) => writes.push(() => ref.set(v, o)),
      };
      const r = await cb(t);
      for (const w of writes) await w();
      return r;
    };
    const p = queue.then(run, run);
    queue = p.catch(() => {});
    return p;
  },
  batch() { const w = []; return { update: (r, v) => w.push(() => r.update(v)), set: (r, v, o) => w.push(() => r.set(v, o)), commit: async () => { for (const f of w) await f(); } }; },
};
const DAY_MS = 86400000;
module.exports = {
  admin: { apps: [1], auth: () => ({}), storage: () => ({}) }, db, FieldValue, Timestamp, DAY_MS,
  daysFromNow: (d) => Timestamp.fromMillis(Date.now() + d * DAY_MS),
  isPremiumUser: (u) => !!(u && u.premiumPlan && u.premiumExpiresAt && u.premiumExpiresAt.toMillis() > Date.now()),
  __store: store,
};
