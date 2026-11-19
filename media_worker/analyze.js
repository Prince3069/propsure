/**
 * Pure video analysis helpers (ffprobe / ffmpeg). No Firebase in here so they
 * can be tested with a local file.
 *
 * Candidate frames are chosen ONLY from the submitted footage:
 *   - too dark / blown out  → rejected
 *   - blurry (low edge energy relative to the clip) → rejected
 *   - near-duplicate of one already chosen (perceptual hash) → rejected
 * The footage is split into scenes (one per space the camera walks through) and
 * each scene gives one wide frame plus a few different views of the same space
 * (for example the cooker, then the sink), so the review screen can group them.
 *
 * Clarity: frames and the shared video get light brightness, noise and
 * sharpness correction and, when possible, steadying. Nothing is added,
 * generated, staged or removed. A human confirms the final set.
 */
const { spawn, execFile } = require('child_process');

const W = 128; const H = 96; // analysis resolution only

function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { maxBuffer: 64 * 1024 * 1024, ...opts }, (err, stdout, stderr) => {
      if (err) { err.stderr = stderr; return reject(err); }
      resolve(stdout);
    });
  });
}

async function probe(file) {
  const out = await run('ffprobe', ['-v', 'error', '-print_format', 'json', '-show_format', '-show_streams', file]);
  const j = JSON.parse(out);
  const v = (j.streams || []).find((s) => s.codec_type === 'video');
  return {
    hasVideo: !!v,
    width: v ? v.width : 0,
    height: v ? v.height : 0,
    codec: v ? v.codec_name : null,
    durationSec: parseFloat((j.format && j.format.duration) || (v && v.duration) || '0') || 0,
    creationTime: (j.format && j.format.tags && j.format.tags.creation_time) || null,
  };
}

function validate(info, limits) {
  if (!info.hasVideo) return 'There is no video in that file.';
  if (info.width < 240 || info.height < 240) return 'The video resolution is too low to use.';
  if (info.durationSec < limits.minVideoSeconds) return `The video is shorter than ${limits.minVideoSeconds} seconds.`;
  if (info.durationSec > limits.maxVideoSeconds) return `The video is longer than ${Math.round(limits.maxVideoSeconds / 60)} minutes. Trim it and try again.`;
  return null;
}

/** Streams 1 fps greyscale thumbnails and returns per-second metrics. */
function sampleMetrics(file, { fps = 2 } = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn('ffmpeg', ['-v', 'error', '-i', file, '-vf', `fps=${fps},scale=${W}:${H},format=gray`, '-f', 'rawvideo', '-pix_fmt', 'gray', 'pipe:1']);
    const size = W * H; let buf = Buffer.alloc(0); const frames = []; let err = '';
    p.stderr.on('data', (d) => { err += d; });
    p.stdout.on('data', (d) => {
      buf = Buffer.concat([buf, d]);
      while (buf.length >= size) { frames.push(frameMetrics(buf.subarray(0, size), frames.length / fps)); buf = buf.subarray(size); }
    });
    p.on('close', (code) => (code === 0 ? resolve(frames) : reject(new Error(`ffmpeg sample failed: ${err}`))));
    p.on('error', reject);
  });
}

function frameMetrics(px, tSec) {
  let sum = 0; let grad = 0;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const v = px[y * W + x]; sum += v;
      if (x + 1 < W) grad += Math.abs(v - px[y * W + x + 1]);
      if (y + 1 < H) grad += Math.abs(v - px[(y + 1) * W + x]);
    }
  }
  const mean = sum / (W * H);
  const sharpness = grad / (2 * W * H);
  // 8x8 average hash
  const bw = W / 8; const bh = H / 8; const cells = [];
  for (let by = 0; by < 8; by++) for (let bx = 0; bx < 8; bx++) {
    let s = 0; for (let y = 0; y < bh; y++) for (let x = 0; x < bw; x++) s += px[(by * bh + y) * W + bx * bw + x];
    cells.push(s / (bw * bh));
  }
  const avg = cells.reduce((a, b) => a + b, 0) / 64;
  let hash = 0n; for (let i = 0; i < 64; i++) if (cells[i] > avg) hash |= 1n << BigInt(i);
  return { tSec, mean, sharpness, hash };
}

function hamming(a, b) { let x = a ^ b; let c = 0; while (x) { c += Number(x & 1n); x >>= 1n; } return c; }
function median(a) { const s = [...a].sort((x, y) => x - y); return s.length ? s[Math.floor(s.length / 2)] : 0; }

/** Splits the footage into scenes: a new scene starts where the picture changes a lot. */
function segmentScenes(frames, { minSceneSec = 2.5, maxScenes = 12, fps = 2 } = {}) {
  if (!frames.length) return [];
  const step = 1 / fps;
  const cuts = [0];
  for (let i = 1; i < frames.length; i++) {
    const d = hamming(frames[i - 1].hash, frames[i].hash);
    const jump = Math.abs(frames[i].mean - frames[i - 1].mean);
    if (d >= 16 || jump >= 30) cuts.push(i);
  }
  let scenes = cuts.map((c, k) => ({ from: c, to: (k + 1 < cuts.length ? cuts[k + 1] : frames.length) - 1 }));
  const len = (sc) => (sc.to - sc.from + 1) * step;
  // Merge scenes that are too short into the one before (or after, for the first).
  let merged = true;
  while (merged && scenes.length > 1) {
    merged = false;
    for (let k = 0; k < scenes.length; k++) {
      if (len(scenes[k]) < minSceneSec) {
        if (k > 0) { scenes[k - 1].to = scenes[k].to; scenes.splice(k, 1); } else { scenes[1].from = scenes[0].from; scenes.splice(0, 1); }
        merged = true; break;
      }
    }
  }
  while (scenes.length > maxScenes) {
    let best = 1; let bestLen = Infinity;
    for (let k = 1; k < scenes.length; k++) { const l = len(scenes[k]); if (l < bestLen) { bestLen = l; best = k; } }
    scenes[best - 1].to = scenes[best].to; scenes.splice(best, 1);
  }
  return scenes.map((sc, index) => ({ index, startSec: frames[sc.from].tSec, endSec: frames[sc.to].tSec + step, from: sc.from, to: sc.to }));
}

function usableFrames(frames) {
  const rejected = []; const usable = new Set();
  const med = median(frames.map((f) => f.sharpness));
  const sharpFloor = Math.max(1.0, med * 0.6);
  for (const f of frames) {
    if (f.mean < 45) rejected.push({ tSec: f.tSec, reason: 'too dark' });
    else if (f.mean > 220) rejected.push({ tSec: f.tSec, reason: 'overexposed' });
    else if (f.sharpness < sharpFloor) rejected.push({ tSec: f.tSec, reason: 'blurry' });
    else usable.add(f);
  }
  return { usable, rejected };
}

/**
 * One wide frame per scene plus up to (perScene - 1) different views of the same
 * space. Every chosen frame carries its scene number so the app can group them.
 * @returns {{ chosen: object[], rejected: {tSec:number, reason:string}[], scenes: object[], coverageWarning: boolean }}
 */
function selectCandidates(frames, { max = 24, perScene = 3, minGap = 2, fps = 2 } = {}) {
  const { usable, rejected } = usableFrames(frames);
  const scenes = segmentScenes(frames, { fps });
  const chosen = [];
  const dupOfChosen = (f) => chosen.some((c) => hamming(c.hash, f.hash) <= 6 || Math.abs(c.tSec - f.tSec) < minGap);
  for (const sc of scenes) {
    const pool = frames.slice(sc.from, sc.to + 1).filter((f) => usable.has(f));
    const mine = [];
    // Wide frame: the sharpest usable frame of the scene that is not a repeat.
    for (const f of [...pool].sort((a, b) => b.sharpness - a.sharpness)) {
      if (!dupOfChosen(f)) { mine.push(Object.assign(f, { scene: sc.index, role: 'wide' })); chosen.push(f); break; }
      rejected.push({ tSec: f.tSec, reason: 'near-duplicate' });
    }
    // Different views of the same space: farthest (by picture) from what is already taken.
    while (mine.length && mine.length < perScene) {
      let best = null; let bestD = 0;
      for (const f of pool) {
        if (mine.includes(f) || dupOfChosen(f)) continue;
        const d = Math.min(...mine.map((m) => hamming(m.hash, f.hash)));
        if (d > bestD) { bestD = d; best = f; }
      }
      if (!best || bestD < 10) break;
      mine.push(Object.assign(best, { scene: sc.index, role: 'detail' })); chosen.push(best);
    }
  }
  chosen.sort((a, b) => a.tSec - b.tSec);
  while (chosen.length > max) {
    // Drop the least useful extra view first (a detail from the busiest scene), never a wide frame.
    const counts = {}; chosen.forEach((c) => { counts[c.scene] = (counts[c.scene] || 0) + 1; });
    const details = chosen.filter((c) => c.role === 'detail').sort((a, b) => counts[b.scene] - counts[a.scene] || a.sharpness - b.sharpness);
    const drop = details[0] || chosen[chosen.length - 1];
    chosen.splice(chosen.indexOf(drop), 1);
  }
  const sceneInfo = scenes.map((sc) => ({ index: sc.index, startSec: sc.startSec, endSec: sc.endSec })).filter((sc) => chosen.some((c) => c.scene === sc.index));
  return { chosen, rejected, scenes: sceneInfo, coverageWarning: chosen.length < 3 };
}

/**
 * Plain-language problems with the recording, with the time they happen, so the
 * agent knows exactly what to film again. Based only on the footage itself.
 */
function analyzeQuality(frames, info, { fps = 2 } = {}) {
  const issues = [];
  const step = 1 / fps;
  const med = median(frames.map((f) => f.sharpness));
  const runs = (test, minSec) => {
    const out = []; let start = null;
    frames.forEach((f, i) => {
      const on = test(f);
      if (on && start === null) start = i;
      if ((!on || i === frames.length - 1) && start !== null) {
        const end = on ? i : i - 1;
        if ((end - start + 1) * step >= minSec) out.push({ fromMs: Math.round(frames[start].tSec * 1000), toMs: Math.round((frames[end].tSec + step) * 1000) });
        start = null;
      }
    });
    return out;
  };
  for (const r of runs((f) => f.mean < 70, 3)) issues.push({ type: 'dark', ...r, tip: 'Too dark here. Open the curtains and switch on the lights, then film this room again.' });
  for (const r of runs((f) => f.mean > 215, 3)) issues.push({ type: 'bright', ...r, tip: 'Too bright here, the window is washing out the room. Stand with your back to the window and film again.' });
  for (const r of runs((f) => f.sharpness < Math.max(1.0, med * 0.5), 2)) issues.push({ type: 'fast', ...r, tip: 'The camera moved too fast or lost focus here. Walk slowly and pause for 2 to 3 seconds on each key spot.' });
  if (info && info.durationSec && info.durationSec < 20) issues.push({ type: 'short', fromMs: 0, toMs: Math.round(info.durationSec * 1000), tip: 'This tour is very short. One to two minutes lets renters see every room properly.' });
  issues.sort((a, b) => (b.toMs - b.fromMs) - (a.toMs - a.fromMs));
  return issues.slice(0, 6);
}

/** Light correction only: noise, brightness and sharpness. Adds and removes nothing. */
function enhanceChain(meanLuma, { video = false } = {}) {
  const f = [video ? 'hqdn3d=1.2:1.0:3:3' : 'hqdn3d=1.5:1.2:2:2'];
  const m = Number.isFinite(meanLuma) ? meanLuma : 120;
  if (m < 110) f.push(`eq=gamma=${Math.min(1.4, 1 + (110 - m) / 220).toFixed(2)}:contrast=1.05`);
  else f.push('eq=contrast=1.03');
  f.push('unsharp=5:5:0.6:5:5:0.0');
  return f.join(',');
}

/** The sharpest of a few frames around [tSec], then one corrected, full-quality extraction. */
async function bestFrame(file, tSec, outJpg, { meanLuma, tmpDir, maxWidth = 1920 } = {}) {
  const fs = require('fs'); const path = require('path');
  const dir = tmpDir || require('os').tmpdir();
  const probeStart = Math.max(0, tSec - 0.4);
  const base = path.join(dir, `pick_${Math.round(tSec * 1000)}_`);
  let bestAt = tSec;
  try {
    await run('ffmpeg', ['-v', 'error', '-y', '-ss', String(probeStart), '-i', file, '-t', '0.8', '-vf', `fps=6,scale='min(${maxWidth},iw)':-2`, '-q:v', '2', `${base}%d.jpg`]);
    const files = fs.readdirSync(dir).filter((n) => n.startsWith(path.basename(base)) && n.endsWith('.jpg')).sort();
    let bestSize = -1;
    files.forEach((n, i) => {
      const size = fs.statSync(path.join(dir, n)).size; // more fine detail → larger JPEG
      if (size > bestSize) { bestSize = size; bestAt = probeStart + i / 6; }
      fs.rmSync(path.join(dir, n), { force: true });
    });
  } catch (_) { bestAt = tSec; }
  await run('ffmpeg', ['-v', 'error', '-y', '-ss', String(bestAt), '-i', file, '-frames:v', '1',
    '-vf', `${enhanceChain(meanLuma)},scale='min(${maxWidth},iw)':-2`, '-q:v', '2', outJpg]);
  return Math.round(bestAt * 1000);
}

/** Kept for callers that want a plain, uncorrected frame. */
function extractFrame(file, tSec, outJpg) {
  return run('ffmpeg', ['-v', 'error', '-y', '-ss', String(tSec), '-i', file, '-frames:v', '1', '-vf', "scale='min(1920,iw)':-2", '-q:v', '2', outJpg]);
}

let _vidstab = null;
async function stabilizeAvailable() {
  if (_vidstab !== null) return _vidstab;
  try { const out = await run('ffmpeg', ['-hide_banner', '-filters']); _vidstab = /vidstabdetect/.test(out) && /vidstabtransform/.test(out); } catch (_) { _vidstab = false; }
  return _vidstab;
}

/** Pass 1 of steadying. Returns the transform file path, or null when unavailable or it fails. */
async function detectShake(file, trfPath) {
  if (!(await stabilizeAvailable())) return null;
  try {
    await run('ffmpeg', ['-v', 'error', '-y', '-i', file, '-vf', `vidstabdetect=shakiness=5:accuracy=9:result=${trfPath}`, '-f', 'null', '-']);
    return trfPath;
  } catch (_) { return null; }
}

/**
 * The shared (not original) video: same walk-through, same pace. Light
 * correction, optional steadying with a very slight crop, never any new content.
 */
async function transcode(file, outMp4, maxHeight, crf, { meanLuma, trf, enhance = true } = {}) {
  const chain = [];
  if (trf) chain.push(`vidstabtransform=input=${trf}:smoothing=20:zoom=2`);
  if (enhance) chain.push(enhanceChain(meanLuma, { video: true }));
  chain.push(`scale=-2:'min(${maxHeight},ih)'`);
  const args = ['-v', 'error', '-y', '-i', file, '-vf', chain.join(','), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', String(crf),
    '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart', outMp4];
  try { return await run('ffmpeg', args); } catch (e) {
    if (!trf) throw e;
    return transcode(file, outMp4, maxHeight, crf, { meanLuma, enhance }); // retry without steadying
  }
}

module.exports = { probe, validate, sampleMetrics, frameMetrics, selectCandidates, segmentScenes, analyzeQuality, enhanceChain, bestFrame, extractFrame, stabilizeAvailable, detectShake, transcode, hamming, median, W, H };
