/**
 * Share pages and sitemap for the website.
 *
 * The website is a Flutter app, which link-preview crawlers (WhatsApp,
 * Facebook, X, Google) cannot read. So a shared link such as
 *   https://<site>/l/<listingId>
 * is answered by this function with a small HTML page that carries the home's
 * title, area, price and picture as Open Graph tags, then sends people on to
 * the real page (/listing/<id>) in the app. Only live homes are shared, and
 * only the area (never an exact address) is shown.
 */
const functions = require('firebase-functions/v1');
const { db } = require('./admin');

const SITE = process.env.SITE_URL || 'https://propsure.africa';

function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function shortNaira(n) {
  const v = Number(n) || 0;
  const fmt = (x, d) => { let s = x.toFixed(d); if (s.includes('.')) s = s.replace(/0+$/, '').replace(/\.$/, ''); return s; };
  if (v >= 1e6) return `₦${fmt(v / 1e6, 2)}m`;
  if (v >= 1e3) return `₦${fmt(v / 1e3, 1)}k`;
  return `₦${Math.round(v)}`;
}

function periodWord(category) {
  const c = String(category || '').toLowerCase();
  if (c === 'for_sale' || c === 'sale' || c === 'for sale') return '';
  if (c === 'short_stay' || c === 'short stay') return 'night';
  return 'year';
}

function page({ title, description, image, url, redirect }) {
  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<title>${esc(title)}</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="${esc(description)}">
<link rel="canonical" href="${esc(url)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Propsure">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${esc(url)}">
${image ? `<meta property="og:image" content="${esc(image)}">\n<meta name="twitter:card" content="summary_large_image">\n<meta name="twitter:image" content="${esc(image)}">` : '<meta name="twitter:card" content="summary">'}
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(description)}">
<meta http-equiv="refresh" content="0; url=${esc(redirect)}">
<style>body{font-family:system-ui,sans-serif;background:#F8F6F0;color:#1A1A2E;margin:0;display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center}a{color:#0F4C3A;font-weight:700}</style>
</head><body><div><p>Opening Propsure…</p><p><a href="${esc(redirect)}">Continue to the home</a></p></div>
<script>location.replace(${JSON.stringify(redirect)});</script></body></html>`;
}

exports.shareListing = functions.https.onRequest(async (req, res) => {
  // Path is /l/<id> (Hosting rewrite). Accept ?id= too, for testing.
  const parts = String(req.path || '').split('/').filter(Boolean);
  const id = (parts[0] === 'l' ? parts[1] : parts[0]) || String(req.query.id || '');
  res.set('Cache-Control', 'public, max-age=300, s-maxage=600');
  try {
    const snap = id && /^[A-Za-z0-9_-]{6,64}$/.test(id) ? await db.collection('listings').doc(id).get() : null;
    const l = snap && snap.exists ? snap.data() : null;
    if (!l || !['active', 'stale'].includes(l.status)) {
      res.status(404).send(page({ title: 'Propsure', description: 'Homes you can see before you visit.', image: null, url: SITE, redirect: '/' }));
      return;
    }
    const loc = l.location || {};
    const area = loc.area || l.area || '';
    const city = loc.city || l.city || '';
    const where = [area, city].filter(Boolean).join(', ');
    const per = periodWord(l.category);
    const price = per ? `${shortNaira(l.price)} / ${per}` : shortNaira(l.price);
    const beds = Number(l.bedrooms) || 0;
    const baths = Number(l.bathrooms) || 0;
    const bits = [];
    if (beds) bits.push(`${beds} bed`);
    if (baths) bits.push(`${baths} bath`);
    const hasVideo = l.videoStatus === 'ready' && l.videoUrl;
    const description = [`${price}${where ? ` in ${where}` : ''}.`, bits.join(' · '), hasVideo ? 'Watch the video tour.' : ''].filter(Boolean).join(' ');
    const image = l.posterUrl || (Array.isArray(l.images) && l.images[0]) || null;
    res.status(200).send(page({
      title: `${l.title || 'Home'} · ${price}`,
      description,
      image,
      url: `${SITE}/l/${id}`,
      redirect: `/listing/${id}`,
    }));
  } catch (e) {
    console.error('shareListing failed', e);
    res.status(200).send(page({ title: 'Propsure', description: 'Homes you can see before you visit.', image: null, url: SITE, redirect: id ? `/listing/${id}` : '/' }));
  }
});

// Lists the home pages search engines can index (live homes only).
exports.sitemap = functions.https.onRequest(async (_req, res) => {
  res.set('Cache-Control', 'public, max-age=3600, s-maxage=3600');
  try {
    const snap = await db.collection('listings').where('status', '==', 'active').limit(2000).get();
    const urls = snap.docs.map((d) => {
      const u = d.data().updatedAt;
      const last = u && u.toDate ? u.toDate().toISOString().slice(0, 10) : null;
      return `<url><loc>${esc(`${SITE}/l/${d.id}`)}</loc>${last ? `<lastmod>${last}</lastmod>` : ''}</url>`;
    });
    res.set('Content-Type', 'application/xml');
    res.status(200).send(`<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>${esc(SITE)}/</loc></url>${urls.join('')}</urlset>`);
  } catch (e) {
    console.error('sitemap failed', e);
    res.status(500).send('error');
  }
});
