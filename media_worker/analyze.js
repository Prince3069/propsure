/**
 * Pure video analysis helpers (ffprobe / ffmpeg). No Firebase in here so they
 * can be tested with a local file.
 *
 * Candidate frames are chosen ONLY from the submitted footage:
 *   - too dark / blown out  → rejected
 *   - blurry (low edge energy relative to the clip) → rejected
 *   - near-duplicate of one already chosen (perceptual hash) → rejected
 * Nothing is generated, enhanced or staged. A human confirms the final set.
 */
const { spawn, execFile } = require('child_process');

const W = 96; const H = 72; // analysis resolution only

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
function sampleMetrics(file, { fps = 1 } = {}) {
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

/**
 * @returns {{ chosen: object[], rejected: {tSec:number, reason:string}[], coverageWarning: boolean }}
 */
function selectCandidates(frames, { max = 8, minGap = 2 } = {}) {
  const rejected = []; const usable = [];
  const med = median(frames.map((f) => f.sharpness));
  const sharpFloor = Math.max(1.5, med * 0.6);
  for (const f of frames) {
    if (f.mean < 45) rejected.push({ tSec: f.tSec, reason: 'too dark' });
    else if (f.mean > 220) rejected.push({ tSec: f.tSec, reason: 'overexposed' });
    else if (f.sharpness < sharpFloor) rejected.push({ tSec: f.tSec, reason: 'blurry' });
    else usable.push(f);
  }
  const chosen = [];
  if (usable.length) {
    const t0 = frames[0].tSec; const t1 = frames[frames.length - 1].tSec + 1;
    const span = (t1 - t0) / max;
    for (let b = 0; b < max; b++) {
      const bucket = usable.filter((f) => f.tSec >= t0 + b * span && f.tSec < t0 + (b + 1) * span).sort((x, y) => y.sharpness - x.sharpness);
      for (const f of bucket) {
        const dup = chosen.some((c) => hamming(c.hash, f.hash) <= 6 || Math.abs(c.tSec - f.tSec) < minGap);
        if (!dup) { chosen.push(f); break; }
        rejected.push({ tSec: f.tSec, reason: 'near-duplicate' });
      }
    }
  }
  chosen.sort((a, b) => a.tSec - b.tSec);
  return { chosen, rejected, coverageWarning: chosen.length < 3 };
}

function extractFrame(file, tSec, outJpg) {
  return run('ffmpeg', ['-v', 'error', '-y', '-ss', String(tSec), '-i', file, '-frames:v', '1', '-vf', "scale='min(1280,iw)':-2", '-q:v', '3', outJpg]);
}

function transcode(file, outMp4, maxHeight, crf) {
  return run('ffmpeg', ['-v', 'error', '-y', '-i', file, '-vf', `scale=-2:'min(${maxHeight},ih)'`, '-c:v', 'libx264', '-preset', 'veryfast', '-crf', String(crf),
    '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart', outMp4]);
}

module.exports = { probe, validate, sampleMetrics, frameMetrics, selectCandidates, extractFrame, transcode, hamming, W, H };
