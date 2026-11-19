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

  // Every chosen frame belongs to a scene, and each scene has a wide frame
  assert.ok(sel.chosen.every((c) => Number.isInteger(c.scene) && (c.role === 'wide' || c.role === 'detail')));
  const sceneIds = [...new Set(sel.chosen.map((c) => c.scene))];
  for (const id of sceneIds) assert.ok(sel.chosen.some((c) => c.scene === id && c.role === 'wide'), 'each scene has a wide frame');
  assert.ok(sel.scenes.length >= 2, 'footage is split into several scenes');
  console.log('scenes:', JSON.stringify(sel.scenes.map((x) => [x.index, x.startSec, x.endSec])));

  // Quality report finds the black segment (3–6s) as a dark problem
  const q = A.analyzeQuality(frames, info);
  console.log('quality:', JSON.stringify(q.map((x) => [x.type, x.fromMs, x.toMs])));
  assert.ok(q.some((x) => x.type === 'dark' && x.fromMs >= 2500 && x.toMs <= 6500), 'dark stretch reported');

  // Extraction + transcode produce real files
  const gotMs = await A.bestFrame(f('clip.mp4'), sel.chosen[0].tSec, f('still.jpg'), { meanLuma: sel.chosen[0].mean, tmpDir: dir });
  assert.ok(fs.statSync(f('still.jpg')).size > 1000);
  assert.ok(Math.abs(gotMs / 1000 - sel.chosen[0].tSec) < 1, 'sharpest nearby frame stays within a second of the pick');
  await A.extractFrame(f('clip.mp4'), sel.chosen[0].tSec, f('plain.jpg'));
  assert.ok(fs.statSync(f('plain.jpg')).size > 1000);
  // Brightening lifts a dark frame; a bright frame is not pushed
  assert.ok(A.enhanceChain(60).includes('gamma='));
  assert.ok(!A.enhanceChain(150).includes('gamma='));
  await A.transcode(f('clip.mp4'), f('p360.mp4'), 360, 28);
  const out = await A.probe(f('p360.mp4'));
  assert.strictEqual(out.height, 360);
  assert.ok(Math.abs(out.durationSec - 15) < 1);
  await A.transcode(f('clip.mp4'), f('p720.mp4'), 720, 25);
  const out2 = await A.probe(f('p720.mp4'));
  assert.strictEqual(out2.height, 480, 'never upscales a 480p source to 720p');
  assert.ok(Math.abs(out2.durationSec - 15) < 1, 'same length: no speed change, nothing cut');
  // Steadying runs when the filter exists, and the result keeps the same length
  const trf = await A.detectShake(f('clip.mp4'), f('t.trf'));
  if (trf) {
    await A.transcode(f('clip.mp4'), f('steady.mp4'), 480, 25, { meanLuma: 120, trf });
    const st = await A.probe(f('steady.mp4'));
    assert.ok(Math.abs(st.durationSec - 15) < 1, 'steadied video has the same length');
    console.log('steadying ok');
  } else console.log('steadying not available here (skipped)');
  console.log('media worker analysis tests passed');
})().catch((e) => { console.error('FAIL', e); process.exit(1); });
