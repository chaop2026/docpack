/*
 * The YouTube Shorts cut — ONE implementation (2026-11-16).
 *
 * Called by make_short.mjs (on its own) and by make_episode.mjs (as part of a
 * full episode build). It used to live inline in make_episode.mjs; moving it
 * here is the whole reason make_short.mjs is not a second recorder.
 *
 * 1080×1920, 30 seconds, structure from the marketing plan §1:
 *
 *   0.0– 1.0s  the pain, with the marker sweeping in  ← MOTION, see below
 *   1.0– 5.0s  the pain, held
 *   5.0–10.0s  why it happens
 *  10.0–25.0s  the fix — real screen recording (track A) or three comparison
 *              cards (track B, which has no tool flow to record)
 *  25.0–29.5s  the result + the landing URL
 *  29.5–30.0s  THE END CARD — the chosen cover + 「プロフィールのリンクから」
 *
 * ── Why the first second moves ─────────────────────────────────────────────
 *
 * Shorts has no thumbnail. The custom-thumbnail upload is a YPP feature this
 * channel does not have, and the Shorts feed does not show one anyway — the
 * first two seconds ARE the thumbnail. A still frame at 0.0s reads as a
 * stalled video to a thumb that is already moving, so the marker sweeps across
 * the pain line instead. It is rendered in the browser, frame by frame, for the
 * same reason the captions are: the Japanese font stays inside Chrome rather
 * than becoming a hardcoded font path in an ffmpeg filter.
 *
 * ── Why the last half second is a still ────────────────────────────────────
 *
 * The opposite problem. The end card is where the viewer decides whether to go
 * anywhere, and it is also the frame the uploader picks as the Shorts cover —
 * dragging the scrubber fully to the right lands on it. A moving end card
 * would make that pick depend on which millisecond the scrubber stopped at.
 *
 * ── Everything is burned in ────────────────────────────────────────────────
 *
 * No subtitle track. Shorts autoplay MUTED and the platform does not reliably
 * render soft subtitles, so text that is not in the pixels is text nobody
 * reads. The cards carry their own text; the screen section gets a caption bar
 * injected into the PAGE before capture.
 *
 * 🔴 There is NO URL on the end card as a link, and none in the description
 * that anyone can click: Shorts descriptions and Shorts comments are not
 * clickable (confirmed 2026-11-01). The end card therefore sends the viewer to
 * the one channel surface that IS clickable — the profile link — in words.
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import { blogUrl, viaUrl } from './episode.mjs';
import { dataUri, ensureMaskable, maskedCount, pngSize, probeVideo, run, startServer } from './capture.mjs';

export const SHORTS = { w: 1080, h: 1920, fps: 30, maxSeconds: 30 };

/* The timeline, in seconds. They sum to SHORTS.maxSeconds and a check below
 * says so — an end card added without taking the time from somewhere would
 * push the file over the cap, and the cap is enforced from ffprobe at the end,
 * which is a late and confusing place to learn it. */
export const SHORTS_SEGMENTS = {
  painWipe: 1.0, painHold: 4.0, why: 5.0, fix: 15.0, done: 4.5, end: 0.5
};

/*
 * A recording is only worth shipping if the tool visibly did its job.
 *
 * Measured on ep03's 契約書 prop: generic detection found seven items but
 * located only one, so the finished frame showed a document with the names,
 * the address, the phone number and the account number still readable and a
 * banner saying 「1か所を隠しました」. That is an advertisement for the tool
 * failing, and on a muted autoplaying Short nobody reads the caption
 * explaining why.
 */
export const SHORTS_MIN_MASKED = 3;

// 「プロフィールのリンクから」 — the end card's whole job. Shorts descriptions
// and comments are not clickable, so this sentence is the only route out, and
// the channel profile's link #1 is where it points
// (content/jp/channel/profile_links.md).
export const END_CARD_LINE = 'プロフィールのリンクから';

const WIPE_FRAMES = 10;

/**
 * Build shorts.mp4 plus its title/description/record for one episode.
 *
 * Returns { status, short } where `status` is the manifest string
 * ('ok: …' | 'failed: …') and `short` is the short_ja.json contents.
 * Never throws for a content reason — a failed Shorts cut must not take the
 * rest of an episode build down with it.
 */
export async function buildShorts(ctx) {
  const {
    browser, epDir, ep, epp, topic, fm, captions = [],
    templatePath, publicDir, fixturesDir, fixtureForDoc, landing,
    slug, mustSentence, record = true, warnings = []
  } = ctx;

  const outDir = path.join(epDir, '.shorts');
  const mp4 = path.join(epDir, 'shorts.mp4');
  const jsonPath = path.join(epDir, 'short_ja.json');

  /* Read BEFORE anything is written. `cover`, `hooks`, `script` and `posted`
   * are NOT this function's to invent — they are a person's decisions (Gate 1)
   * and video-story's output. A rebuild of the VIDEO must not rewrite them;
   * make_episode.mjs learned this the hard way with `posted` (2026-10-25,
   * a --no-demo rebuild reset `posted.x` and dropped the pinned tweet URL). */
  const prev = fs.existsSync(jsonPath)
    ? (() => { try { return JSON.parse(fs.readFileSync(jsonPath, 'utf8')); } catch { return {}; } })()
    : {};

  const total = Object.values(SHORTS_SEGMENTS).reduce((a, b) => a + b, 0);
  if (Math.abs(total - SHORTS.maxSeconds) > 0.001) {
    // A loud failure here beats an ffprobe cap violation after four minutes of
    // rendering, and beats a silently 30.5s file if the cap ever gets relaxed.
    throw new Error(`SHORTS_SEGMENTS sum to ${total}s, not ${SHORTS.maxSeconds}s — `
      + 'adding a segment means taking the time from another one');
  }

  /* Which cover the end card uses.
   *
   * Chosen by a person at Gate 1 and recorded in short_ja.json as `cover`.
   * Defaulting to thumb_short_a.png would make the default look like a
   * decision, so an absent choice is reported — but it does not stop the
   * build, because a Short without an end card is still worth having and the
   * manifest says which one it is. */
  const coverName = prev.cover || null;
  let coverFile = coverName ? path.join(epDir, coverName) : null;
  if (coverFile && !fs.existsSync(coverFile)) {
    warnings.push(`shorts: short_ja.json names cover "${coverName}" but the file does not exist — run make_thumbnail.mjs ${ep}`);
    coverFile = null;
  }
  if (!coverName) {
    warnings.push('shorts: short_ja.json has no `cover` — Gate 1 has not picked one of the two thumbnails yet; '
      + 'the end card falls back to the closing card');
  } else if (prev.cover_provisional) {
    /* A provisional cover is not a choice, and it must not read as one.
     *
     * The build needs SOME image to put on the end card, and leaving it out
     * until Gate 1 means the video cannot be finished before the meeting that
     * reviews the video. So a provisional value is allowed — and it is
     * announced every single run, and the flag is carried forward until a
     * person clears it. A default that stops being mentioned is a default that
     * becomes the decision. */
    warnings.push(`shorts: cover "${coverName}" is PROVISIONAL (cover_provisional: true) — `
      + 'Gate 1 has not confirmed it. Clear the flag in short_ja.json when it is chosen');
  }

  const short = {
    // Carried forward like the human fields below: the note explaining which
    // half of this file is authored and which half is measured is itself
    // authored, and a rebuild that deletes the instructions for reading the
    // file is a rebuild that makes the file harder to read every time it runs.
    ...(prev._readme ? { _readme: prev._readme } : {}),
    ep,
    generated_by: 'scripts/content/lib/shorts.mjs',
    size: `${SHORTS.w}x${SHORTS.h}`,
    segments: { ...SHORTS_SEGMENTS },
    // Carried forward, never recomputed — see `prev` above.
    cover: prev.cover ?? null,
    cover_provisional: prev.cover_provisional ?? null,
    hooks: prev.hooks ?? null,
    script: prev.script ?? null,
    posted: prev.posted ?? null
  };

  let status;
  try {
    fs.rmSync(outDir, { recursive: true, force: true });
    fs.mkdirSync(outDir, { recursive: true });

    /* ── the cards ─────────────────────────────────────────────────────── */
    const cardPage = await browser.newPage({ viewport: { width: SHORTS.w, height: SHORTS.h }, deviceScaleFactor: 1 });
    await cardPage.goto(pathToFileURL(templatePath).href);
    await Promise.race([ cardPage.evaluate(() => document.fonts.ready), cardPage.waitForTimeout(6000) ]);

    const shot = async (file) => {
      await cardPage.locator('#card').screenshot({ path: file });
      const size = pngSize(file);
      if (size.width !== SHORTS.w || size.height !== SHORTS.h) {
        throw new Error(`${path.basename(file)} is ${size.width}×${size.height}, not ${SHORTS.w}×${SHORTS.h}`);
      }
      return file;
    };

    // The pain line is fm.hook — the same sentence that opens the X thread,
    // which S10 made a rule about. One opener per episode, written once.
    const painFit = await cardPage.evaluate((d) => window.SF_CARD('pain', d),
      { tag: 'よくある差し戻し', text: fm.hook });
    if (painFit.overflowed) warnings.push(`shorts card pain: text still overflows at the ${Math.round(painFit.scale * 100)}% floor — shorten it`);

    /* The opening sweep. Frames are screenshots of the SAME card with the
     * marker clipped to a growing width, so the type never reflows — a wipe
     * that re-laid-out the sentence would read as a glitch. */
    const wipeFrames = [];
    for (let i = 0; i < WIPE_FRAMES; i++) {
      const pct = Math.round((i / (WIPE_FRAMES - 1)) * 100);
      await cardPage.evaluate((p) => window.SF_CARD_WIPE(p), pct);
      wipeFrames.push(await shot(path.join(outDir, `pain${String(i).padStart(3, '0')}.png`)));
    }
    const painFull = wipeFrames[wipeFrames.length - 1];

    const cards = {};
    /* What each card actually said, recorded as it is rendered.
     *
     * short_ja.json already carries `script` — video-story's PLAN for the four
     * segments. The wording of why / compare / done is owned by this file, so
     * the plan and the video can disagree and nothing would say so. Writing
     * both down means a reader of short_ja.json can see the divergence instead
     * of having to open the mp4. (Images are excluded: `end` carries a data
     * URI, and a base64 PNG in a JSON record is not a record of anything.) */
    const rendered = { pain: { tag: 'よくある差し戻し', text: fm.hook } };
    const renderCard = async (kind, data, name) => {
      const fit = await cardPage.evaluate(([ k, d ]) => window.SF_CARD(k, d), [ kind, data ]);
      if (fit.overflowed) warnings.push(`shorts card ${name}: text still overflows at the ${Math.round(fit.scale * 100)}% floor — shorten it`);
      const { img, fallbackImg, ...textOnly } = data;
      rendered[name] = textOnly;
      cards[name] = await shot(path.join(outDir, `card_${name}.png`));
    };

    await renderCard('why', {
      text: '黒い四角を重ねただけでは、\n下の文字が残ることがあります。',
      note: 'PDFの文字層はコピーできてしまいます。'
    }, 'why');

    /* The comparison card is built for EVERY episode, not just track B.
     *
     * It is track B's middle 15 seconds by design, and it is also what track A
     * falls back to when the recording does not clear SHORTS_MIN_MASKED or the
     * document has no dummy. The first version only built it for track B, so a
     * track A fallback held the "why" card for fifteen seconds — a Short that
     * says nothing for half its length. The card costs one screenshot. */
    await renderCard('compare', { text: '隠し方で結果が変わります', items: [
      { ok: false, txt: '付箋を貼って撮影 — 光で透けることがある' },
      { ok: false, txt: '画像編集アプリで黒い四角 — 文字層が残る' },
      { ok: true, txt: '画像に平坦化 — 下に原文が残らない' }
    ] }, 'compare');

    await renderCard('done', topic.track === 'A'
      ? { text: '画像に平坦化されるので、\n黒塗りの下に原文は残りません。',
          note: 'ファイルはブラウザの中だけで処理されます。', url: viaUrl({ landing, channel: 'youtube', epp }) }
      : { text: '提出先の指示に合わせて\n隠す範囲を選べます。',
          note: 'ファイルはブラウザの中だけで処理されます。', url: viaUrl({ landing, channel: 'youtube', epp }) },
      'done');

    /* The end card. The cover image is passed in as a data: URI rather than a
     * path — the template is opened from scripts/, the image lives in
     * content/, and a relative file:// reference between them resolves to
     * nothing and renders as an empty box without erroring. */
    await renderCard('end', {
      img: coverFile ? dataUri(coverFile) : null,
      fallbackImg: coverFile ? null : dataUri(cards.done),
      line: END_CARD_LINE,
      // The SHORTS title, not the article title. The article title is written
      // for search (32 chars, bracketed qualifier) and wrapped to three lines
      // in the end card's bar, where it pushed the one sentence that matters
      // off its own line. Measured 2026-11-16.
      sub: `第${epp}回 ${(topic.shorts_title_ja || fm.title).trim()}`
    }, 'end');

    await cardPage.close();

    /* ── the fix section ───────────────────────────────────────────────── */
    /* Track A records the tool at a PHONE viewport with deviceScaleFactor 2,
     * so the frames come out 1080×1920 natively — scaling a 1080-wide desktop
     * layout down to a phone frame would make the app's own text unreadable,
     * which is the mistake the guide PDF already made once (S9 §E). */
    let fixFrames = [];
    let masked = null;
    let srv;
    if (topic.track === 'A' && record && fixtureForDoc[topic.doc]) {
      try {
        srv = await startServer({ publicDir, fixturesDir });
        const port = srv.address().port;
        const vp = await browser.newPage({
          viewport: { width: SHORTS.w / 2, height: SHORTS.h / 2 }, deviceScaleFactor: 2
        });
        const url = `http://127.0.0.1:${port}/safe/?lang=ja&purpose=${topic.purpose}&from=direct`;
        const resp = await vp.goto(url, { waitUntil: 'load' });
        if (!resp || !resp.ok()) throw new Error(`${url} returned ${resp ? resp.status() : 'no response'}`);
        if (!(await vp.locator('#fileInput').count())) throw new Error('no #fileInput — wrong document?');

        // Caption bar, injected into the page (not drawn by ffmpeg) so the
        // Japanese font stays inside the browser.
        await vp.evaluate(() => {
          const bar = document.createElement('div');
          bar.id = '__scap';
          bar.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:9999;'
            + 'background:rgba(23,20,15,.94);color:#fff;'
            + 'font:700 25px/1.5 "Hiragino Kaku Gothic ProN","Noto Sans JP",sans-serif;'
            + 'padding:22px 24px;white-space:pre-line;min-height:104px';
          document.body.appendChild(bar);
          window.__scap = (t) => { bar.textContent = t; };
        });
        const caps = captions.length === 3 ? captions : [
          '① PDF・写真をドラッグ',
          `② 「提出目的：${topic.purpose}」を選ぶ`,
          '③ ダウンロード — 下に原文は残りません'
        ];
        const setCap = (t) => vp.evaluate((x) => window.__scap(x), t);

        let n = 0;
        const grab = async (count) => {
          for (let i = 0; i < count; i++) {
            await vp.screenshot({ path: path.join(outDir, `fix${String(n).padStart(3, '0')}.png`) });
            n++;
            if (i < count - 1) await vp.waitForTimeout(400);
          }
        };

        await setCap(caps[0]);
        await grab(4);
        await vp.setInputFiles('#fileInput', path.join(fixturesDir, fixtureForDoc[topic.doc]));
        await vp.waitForFunction(
          () => Array.isArray(pages) && pages.length > 0 && document.getElementById('docWrap').style.display === 'flex',
          { timeout: 300000 }
        );
        await setCap(caps[1]);
        await vp.locator('#jpBar').scrollIntoViewIfNeeded().catch(() => {});
        await grab(5);
        await ensureMaskable(vp);
        masked = await maskedCount(vp);
        if (masked < SHORTS_MIN_MASKED) {
          throw new Error(`the tool located only ${masked} region(s) on this document `
            + `(floor ${SHORTS_MIN_MASKED}) — a Short showing a half-redacted page advertises the opposite of the product`);
        }
        await vp.click('#btnMake');
        await vp.waitForFunction(() => document.getElementById('result').style.display === 'block', { timeout: 120000 });
        await setCap(caps[2]);
        await vp.locator('#result').scrollIntoViewIfNeeded().catch(() => {});
        await vp.waitForTimeout(400);
        await grab(6);
        await vp.close();
        fixFrames = fs.readdirSync(outDir).filter((f) => f.startsWith('fix')).sort();
        if (fixFrames.length < 6) throw new Error(`only ${fixFrames.length} fix frames`);
      } catch (e) {
        // Partial by design: a failed recording falls back to comparison cards
        // rather than losing the whole Short.
        warnings.push(`shorts: screen recording failed (${e.message}) — using comparison cards instead`);
        fixFrames = [];
      } finally {
        if (srv) srv.close();
      }
    }

    /* ── stitch ────────────────────────────────────────────────────────── */
    const segs = [];
    const still = (file, seconds, pad = '0xF7F5EF') => {
      const out = path.join(outDir, `seg${segs.length}.mp4`);
      run('ffmpeg', [ '-y', '-loop', '1', '-i', file, '-t', String(seconds),
        '-r', String(SHORTS.fps), '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        '-vf', `scale=${SHORTS.w}:${SHORTS.h}:force_original_aspect_ratio=decrease,pad=${SHORTS.w}:${SHORTS.h}:(ow-iw)/2:(oh-ih)/2:color=${pad}`,
        out ]);
      segs.push(out);
    };
    const fromFrames = (pattern, count, seconds, pad = '0xF7F5EF') => {
      const out = path.join(outDir, `seg${segs.length}.mp4`);
      run('ffmpeg', [ '-y', '-framerate', String(count / seconds), '-i', pattern,
        '-r', String(SHORTS.fps), '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        '-vf', `scale=${SHORTS.w}:${SHORTS.h}:force_original_aspect_ratio=decrease,pad=${SHORTS.w}:${SHORTS.h}:(ow-iw)/2:(oh-ih)/2:color=${pad}`,
        out ]);
      segs.push(out);
    };

    fromFrames(path.join(outDir, 'pain%03d.png'), WIPE_FRAMES, SHORTS_SEGMENTS.painWipe);
    still(painFull, SHORTS_SEGMENTS.painHold);
    still(cards.why, SHORTS_SEGMENTS.why);
    if (fixFrames.length) {
      // The recording, stretched to exactly the fix window so the total stays
      // at 30s whatever the frame count turned out to be.
      fromFrames(path.join(outDir, 'fix%03d.png'), fixFrames.length, SHORTS_SEGMENTS.fix, '0x111111');
    } else {
      still(cards.compare, SHORTS_SEGMENTS.fix);
    }
    still(cards.done, SHORTS_SEGMENTS.done);
    still(cards.end, SHORTS_SEGMENTS.end);

    const listFile = path.join(outDir, 'concat.txt');
    fs.writeFileSync(listFile, segs.map((f) => `file '${f.replace(/'/g, "'\\\\''")}'`).join('\n') + '\n');
    run('ffmpeg', [ '-y', '-f', 'concat', '-safe', '0', '-i', listFile, '-c', 'copy', '-movflags', '+faststart', mp4 ]);

    /* ── verify from the FILE, not from what we asked for ──────────────── */
    const meta = probeVideo(mp4);
    if (meta.width !== SHORTS.w || meta.height !== SHORTS.h) {
      throw new Error(`shorts.mp4 is ${meta.width}×${meta.height}, not ${SHORTS.w}×${SHORTS.h}`);
    }
    if (!(meta.duration > 0) || meta.duration > SHORTS.maxSeconds + 0.5) {
      throw new Error(`shorts.mp4 is ${meta.duration.toFixed(2)}s, over the ${SHORTS.maxSeconds}s cap`);
    }

    /* The frame the uploader picks as the cover.
     *
     * Shorts custom thumbnails are a YPP feature this channel does not have,
     * so the only cover available is a frame OF THE VIDEO — which is why the
     * end card exists and why it is a still. Recorded from the measured
     * duration rather than from the nominal 30s: if a segment rounded, the
     * window moves, and an instruction pointing at 29.5s of a 29.8s file
     * lands on the closing card instead of the cover. */
    const endStart = Math.max(0, meta.duration - SHORTS_SEGMENTS.end);

    /* ── title and description ─────────────────────────────────────────── */
    // Title: question form, JA, <=20 chars + 3 hashtags (marketing plan §6-3).
    // Taken from topics.json rather than invented here, and TRUNCATION IS NOT
    // SILENT — an over-length title is reported the same way an over-length
    // tweet is, because a headline cut at a byte boundary is one the author
    // did not write.
    const shortsTitle = (topic.shorts_title_ja || fm.title).trim();
    if ([ ...shortsTitle ].length > 20) {
      warnings.push(`shorts_title_ja: ${[ ...shortsTitle ].length}字 — 20字以内が望ましい(topics.json に shorts_title_ja を足す)`);
    }
    const tags = (topic.shorts_tags || [ '#黒塗り', '#個人情報', '#提出書類' ]).slice(0, 3);
    fs.writeFileSync(path.join(epDir, 'shorts_title_ja.txt'), `${shortsTitle} ${tags.join(' ')}\n`);

    /* The description still PRINTS the URLs, and they are still not clickable.
     *
     * That is deliberate and it is not a contradiction: a reader who wants the
     * article can read the address and type it, and the text is also what the
     * uploader copies into the long-form description where links DO work. What
     * changed in 2026-11-16 is the pinned comment and the end card, which now
     * send people to the profile link instead of pretending these are links.
     * content/jp/channel/README.md holds the table of which surface is which. */
    fs.writeFileSync(path.join(epDir, 'shorts_desc_ja.txt'), [
      fm.hook,
      '',
      ...fm.bullets.map((b, i) => `${[ '①', '②', '③' ][i]}${b}`),
      '',
      mustSentence,
      '',
      `くわしい手順は ${END_CARD_LINE}（このチャンネルのプロフィール）`,
      '',
      `くわしく: ${blogUrl({ slug, channel: 'youtube', epp })}`,
      `試す: ${viaUrl({ landing, channel: 'youtube', epp })}`,
      '',
      tags.join(' ')
    ].join('\n') + '\n');

    const kb = Math.round(fs.statSync(mp4).size / 1024);
    status = `ok: ${meta.duration.toFixed(1)}s, ${meta.width}x${meta.height}, ${kb}KB, `
      + `${fixFrames.length ? `${fixFrames.length} recorded frames` : 'cards only'}, `
      + `end card ${coverFile ? `from ${path.basename(coverFile)}` : 'from the closing card (no Gate 1 choice)'}`;

    Object.assign(short, {
      duration_sec: Math.round(meta.duration * 100) / 100,
      track: topic.track,
      rendered_segments: rendered,
      fix_source: fixFrames.length ? 'screen recording' : 'comparison cards',
      recorded_frames: fixFrames.length,
      masked_regions: masked,
      end_card: {
        from: coverFile ? path.basename(coverFile) : null,
        fell_back_to_closing_card: !coverFile,
        line: END_CARD_LINE,
        starts_at_sec: Math.round(endStart * 100) / 100
      },
      // What the uploader types into the frame picker. The window is given as
      // well as the point: the picker is a scrubber, not a number field, and
      // "drag it fully to the right" is the instruction that actually works.
      thumbnail_frame_sec: Math.round(endStart * 100) / 100,
      thumbnail_frame_window: [ Math.round(endStart * 100) / 100, Math.round(meta.duration * 100) / 100 ],
      warnings: [ ...warnings ]
    });

    fs.rmSync(outDir, { recursive: true, force: true });
  } catch (e) {
    status = `failed: ${e.message}`;
    warnings.push(`shorts.mp4: ${e.message}`);
    Object.assign(short, { failed: e.message, warnings: [ ...warnings ] });
    // Intermediates are left behind on failure — they are the only evidence of
    // how far the build got, same rule as the demo frames.
  }

  fs.writeFileSync(jsonPath, JSON.stringify(short, null, 2) + '\n');
  return { status, short };
}
