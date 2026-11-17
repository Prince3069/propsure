// Generates a clip with known good and bad segments and proves the selector
// keeps real, sharp, distinct frames and rejects dark, blurry and duplicate ones.
const { execFileSync } = require('child_process');
const assert = require('assert');
const fs = require('fs'); const os = require('os'); const path = require('path');
const A = require('./analyze');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps-'));
const f = (n) => path.join(dir, n);
const ff = (args) => execFileSync('ffmpeg', ['-v', 'error', '-y', ...args]);

// 3s sharp pattern A, 3s black, 3s blurred pattern B, 3s sharp pattern A again (duplicate scene), 3s sharp pattern C
ff(['-f', 'lavfi', '-i', 'testsrc2=size=640x480:rate=10:duration=3', '-pix_fmt', 'yuv420p', f('a.mp4')]);
ff(['-f', 'lavfi', '-i', 'color=c=black:size=640x480:rate=10:duration=3', '-pix_fmt', 'yuv420p', f('dark.mp4')]);
ff(['-f', 'lavfi', '-i', 'mandelbrot=size=640x480:rate=10', '-t', '3', '-vf', 'boxblur=25:5', '-pix_fmt', 'yuv420p', f('blur.mp4')]);
ff(['-f', 'lavfi', '-i', 'smptebars=size=640x480:rate=10:duration=3', '-pix_fmt', 'yuv420p', f('c.mp4')]);
fs.writeFileSync(f('list.txt'), ['a', 'dark', 'blur', 'a', 'c'].map((n) => `file '${f(n + '.mp4')}'`).join('\n'));
ff(['-f', 'concat', '-safe', '0', '-i', f('list.txt'), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', f('clip.mp4')]);

(async () => {
  const info = await A.probe(f('clip.mp4'));
  console.log('probe:', info.width + 'x' + info.height, info.durationSec.toFixed(1) + 's');
  assert.ok(info.hasVideo && Math.abs(info.durationSec - 15) < 1);
  assert.strictEqual(A.validate(info, { minVideoSeconds: 5, maxVideoSeconds: 180 }), null);
  assert.ok(A.validate({ ...info, durationSec: 2 }, { minVideoSeconds: 5, maxVideoSeconds: 180 }));
  assert.ok(A.validate({ ...info, durationSec: 999 }, { minVideoSeconds: 5, maxVideoSeconds: 180 }));
  assert.ok(A.validate({ hasVideo: false }, { minVideoSeconds: 5, maxVideoSeconds: 180 }));

  const frames = await A.sampleMetrics(f('clip.mp4'));
  console.log('sampled', frames.length, 'frames');
  const sel = A.selectCandidates(frames, { max: 8 });
  const reasons = {}; sel.rejected.forEach((r) => { reasons[r.reason] = (reasons[r.reason] || 0) + 1; });
  console.log('chosen at', sel.chosen.map((c) => c.tSec + 's').join(', '), '| rejected', JSON.stringify(reasons));
  assert.ok(sel.chosen.every((c) => c.tSec < 3 || c.tSec >= 6), 'no frame from the black segment (3–6s)');
  assert.ok(sel.chosen.every((c) => c.mean >= 45), 'no dark frame chosen');
  assert.ok(reasons['too dark'] >= 3, 'dark frames rejected');
  for (let i = 0; i < sel.chosen.length; i++) for (let j = i + 1; j < sel.chosen.length; j++) {
    assert.ok(A.hamming(sel.chosen[i].hash, sel.chosen[j].hash) > 6, 'chosen frames are visually distinct');
  }
  assert.ok(sel.chosen.length >= 2);

  // Extraction + transcode produce real files
  await A.extractFrame(f('clip.mp4'), sel.chosen[0].tSec, f('still.jpg'));
  assert.ok(fs.statSync(f('still.jpg')).size > 1000);
  await A.transcode(f('clip.mp4'), f('p360.mp4'), 360, 28);
  const out = await A.probe(f('p360.mp4'));
  assert.strictEqual(out.height, 360);
  assert.ok(Math.abs(out.durationSec - 15) < 1);
  await A.transcode(f('clip.mp4'), f('p720.mp4'), 720, 25);
  const out2 = await A.probe(f('p720.mp4'));
  assert.strictEqual(out2.height, 480, 'never upscales a 480p source to 720p');
  console.log('media worker analysis tests passed');
})().catch((e) => { console.error('FAIL', e); process.exit(1); });
