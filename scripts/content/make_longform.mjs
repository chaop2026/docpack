#!/usr/bin/env node
/*
 * SafeFile JP — the monthly long-form cut's DRAFT.
 *
 *   node scripts/content/make_longform.mjs 2026-11
 *
 * Input  : content/jp/topics.json                       (which episodes that month)
 *          content/jp/epNN/post_ja.md                    (hook, title, bullets)
 *          content/jp/channel/upload_default_description_ja.md  (the description template)
 * Output : content/jp/longform/YYYY-MM/script_ja.md      the narration outline
 *          content/jp/longform/YYYY-MM/description_ja.txt the paste-ready description
 *          content/jp/longform/YYYY-MM/manifest.json      what was used and what is missing
 *
 * ── This produces a DRAFT, and says so in the file ─────────────────────────
 *
 * It does not render video. The monthly cut is 3–5 minutes of a person
 * talking over screen capture, and nothing here can write that. What it CAN
 * do without guessing is the part that is derivable: which four episodes the
 * month contains, in which order, with which hooks, which chapter marks fall
 * out of the per-section budget, and what the description has to say.
 *
 * ── Why the long-form exists at all (2026-11-16) ───────────────────────────
 *
 * Shorts descriptions and Shorts comments are not clickable. A Shorts-only
 * channel therefore has exactly one route to the site — the channel's profile
 * link — and that route requires the viewer to leave the feed, open the
 * channel and look. A long-form video's description IS clickable and its
 * first two lines are above the fold. One of these a month is what turns the
 * Shorts from reach into visits, and it is also what the Shorts can point at
 * with the "related video" link.
 *
 * Requires: node. No browser, no ffmpeg — there is nothing to render yet.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { LANDING_PATH, blogUrl, parseFrontmatter, slugFor, viaUrl } from './lib/episode.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..', '..');
const CONTENT = path.join(REPO, 'content', 'jp');
const TEMPLATE = path.join(CONTENT, 'channel', 'upload_default_description_ja.md');

const { RULES, runForbidden, mustLineViolations } =
  await import(pathToFileURL(path.join(__dirname, 'guard_rules.mjs')).href);

const CHANNEL = 'yt_long';

/* The shape of the cut. Four episodes is the usual month; the budget divides
 * whatever is actually there, so a five-Monday month does not silently make a
 * six-minute video out of a five-minute plan. */
const INTRO_SEC = 20;
const OUTRO_SEC = 40;
const TARGET_SEC = { min: 180, max: 300 };

const die = (code, msg) => { console.error(msg); process.exit(code); };

/* ── args ─────────────────────────────────────────────────────────────────── */
const month = process.argv[2];
if (!month || !/^\d{4}-\d{2}$/.test(month)) {
  die(2, 'usage: node scripts/content/make_longform.mjs <YYYY-MM>   e.g. 2026-11');
}

/* ── which episodes ───────────────────────────────────────────────────────── */
/* By `publish_on`, the Monday the blog post goes live — the same field the
 * weekly schedule runs on. Picking by folder number would put ep05 in the
 * month ep05 was WRITTEN, which is not when anyone saw it. */
const plan = JSON.parse(fs.readFileSync(path.join(CONTENT, 'topics.json'), 'utf8'));
const episodes = plan.episodes
  .filter((e) => String(e.publish_on || '').startsWith(month))
  .filter((e) => !e.blocked_until)
  .sort((a, b) => a.ep - b.ep);

if (!episodes.length) {
  die(2, `no episode in content/jp/topics.json has publish_on starting ${month}.\n`
    + `  months present: ${[ ...new Set(plan.episodes.map((e) => String(e.publish_on || '').slice(0, 7))) ].filter(Boolean).join(', ')}`);
}

/* ── each episode's own words ─────────────────────────────────────────────── */
const warnings = [];
const parts = episodes.map((topic) => {
  const epp = String(topic.ep).padStart(2, '0');
  const postPath = path.join(CONTENT, `ep${epp}`, 'post_ja.md');
  if (!fs.existsSync(postPath)) {
    // Stated, not invented. A month whose articles are not written yet gets a
    // draft that says which ones are missing, rather than a draft with four
    // plausible-looking summaries nobody wrote.
    warnings.push(`ep${epp}: post_ja.md does not exist — its section is a placeholder`);
    return { topic, epp, missing: true };
  }
  const { data: fm } = parseFrontmatter(fs.readFileSync(postPath, 'utf8'));
  return { topic, epp, fm, missing: false };
});

const landing = LANDING_PATH[episodes[0].landing] || LANDING_PATH.nyusatsu;

/* ── chapter marks ────────────────────────────────────────────────────────── */
/* Derived from the budget so the numbers in the description and the numbers in
 * the script cannot disagree. ⚠️ They are a PLAN: the real video is edited by
 * a person, and a chapter mark that points at the wrong second sends every
 * viewer who clicks it somewhere confusing. The checklist says to re-time them
 * after the edit, and the draft repeats it at the top. */
const bodySec = Math.max(60, Math.round((TARGET_SEC.min + TARGET_SEC.max) / 2) - INTRO_SEC - OUTRO_SEC);
const perEp = Math.floor(bodySec / parts.length);
const mmss = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;

let t = 0;
const chapters = [ { at: 0, label: 'この動画で扱うこと' } ];
t = INTRO_SEC;
for (const p of parts) {
  chapters.push({ at: t, label: `第${p.epp}回 ${p.topic.shorts_title_ja || p.topic.title_ja}` });
  t += perEp;
}
chapters.push({ at: t, label: '提出前の確認' });
const totalSec = t + OUTRO_SEC;
if (totalSec < TARGET_SEC.min || totalSec > TARGET_SEC.max) {
  warnings.push(`planned length ${mmss(totalSec)} is outside the ${mmss(TARGET_SEC.min)}–${mmss(TARGET_SEC.max)} target`);
}

/* ── the description, from the channel's own template ─────────────────────── */
/* Read from content/jp/channel/upload_default_description_ja.md rather than
 * written here. A human pasting the template by hand and this script have to
 * produce the same text; two templates means one of them is the stale one and
 * nothing says which. */
if (!fs.existsSync(TEMPLATE)) die(2, `missing ${path.relative(REPO, TEMPLATE)} — the description template`);
const tplDoc = fs.readFileSync(TEMPLATE, 'utf8');
const fence = tplDoc.match(/```\n([\s\S]*?)```/);
if (!fence) {
  die(2, `${path.relative(REPO, TEMPLATE)} has no \`\`\` block — that block IS the template`);
}

const firstWithHook = parts.find((p) => !p.missing && p.fm.hook);
if (!firstWithHook) warnings.push('no episode this month has a hook — the first line of the description is a placeholder');

const filled = fence[1]
  .replaceAll('{{MONTH}}', month)
  .replaceAll('{{HOOK}}', firstWithHook ? firstWithHook.fm.hook : '【痛みの1行をここに — その月の先頭回の hook】')
  // No `ep` on the main CTA: this video is four episodes, not one. See the
  // template's own section on why.
  .replaceAll('{{LANDING}}', `https://slimfile.net${landing}?via=${CHANNEL}`)
  .replaceAll('{{CHAPTERS}}', chapters.map((c) => `${mmss(c.at)} ${c.label}`).join('\n'))
  .replaceAll('{{ARTICLES}}', parts
    .map((p) => `第${p.epp}回 ${blogUrl({ slug: slugFor(p.topic), channel: CHANNEL, epp: p.epp })}`)
    .join('\n'));

const leftover = filled.match(/\{\{[A-Z_]+\}\}/g);
if (leftover) die(1, `the template still contains ${leftover.join(', ')} — this script does not know how to fill it`);

/* ── guards ───────────────────────────────────────────────────────────────── */
/* The description is published text, so it is checked like published text.
 * The script outline is too — it is what the narration is read from, and a
 * forbidden claim spoken aloud is still a forbidden claim. */
const scriptMd = [
  `<!-- generated by scripts/content/make_longform.mjs — ${month}. DRAFT. -->`,
  `# 長編ガイド ${month} — 構成案`,
  '',
  '> ⚠️ **これは下書きだ。** 本編の編集は人がやる。ここにあるのは構成・ナレーション案・',
  '> 章立てで、**章の秒数は計画値**だ。編集が終わったら実際の秒数に直すこと —',
  '> ズレた目次は、押した人を別の場所に送る。',
  '',
  `計画尺 **${mmss(totalSec)}**（目標 ${mmss(TARGET_SEC.min)}–${mmss(TARGET_SEC.max)}） / `
    + `${parts.length}回分 / 1回あたり約 ${mmss(perEp)}`,
  '',
  '## 0. つかみ（' + mmss(INTRO_SEC) + '）',
  '',
  firstWithHook
    ? `「${firstWithHook.fm.hook}」から入る。この月のショート${parts.length}本が答えている問いを1つにまとめる。`
    : '【痛みの1行 — その月の先頭回の hook から】',
  '',
  ...parts.flatMap((p) => {
    const head = `## 第${p.epp}回 ${p.topic.title_ja}  （${mmss(chapters.find((c) => c.label.startsWith(`第${p.epp}回`)).at)}〜）`;
    if (p.missing) {
      return [ head, '', `⚠️ **content/jp/ep${p.epp}/post_ja.md がまだない。** 記事を書いてから再生成する。`, '' ];
    }
    return [
      head, '',
      `**痛み**: ${p.fm.hook}`, '',
      '**話すこと**:',
      ...p.fm.bullets.map((b, i) => `${i + 1}. ${b}`), '',
      `**画面**: ${p.topic.doc ? `${p.topic.doc} のダミーで、提出目的「${p.topic.purpose}」の自動黒塗りを見せる` : '該当のダミー書類がない回 — 比較カードで代替'}`,
      ''
    ];
  }),
  `## 提出前の確認（${mmss(chapters[chapters.length - 1].at)}〜）`,
  '',
  '3点だけ繰り返す。',
  '',
  '1. 隠した範囲が提出先の指示と合っているか',
  '2. 審査に必要な項目（氏名・事業所名など）まで消していないか',
  '3. 出力が画像に平坦化されているか（文字層が残っていないか）',
  '',
  RULES.mustSentence,
  '',
  '## 説明欄',
  '',
  '`description_ja.txt` をそのまま貼る。**最初の2行が折りたたみの上**に入る。',
  '',
  '## ショートからの導線',
  '',
  'この月のショート' + parts.length + '本すべてに、「関連動画」としてこの動画を設定する。',
  '⚠️ 高度な機能（電話認証）が有効になっていないと設定できない。',
  ''
].join('\n');

const violations = [
  ...runForbidden([
    [ `longform ${month} description_ja.txt`, filled ],
    [ `longform ${month} script_ja.md`, scriptMd ]
  ]),
  ...mustLineViolations(`longform ${month} description_ja.txt`, filled)
];
if (violations.length) {
  console.error(`\n🔴 ${month}: ${violations.length} guard violation(s) — nothing was written:\n`);
  violations.forEach((v) => console.error('  - ' + v));
  process.exit(1);
}

/* ── write ────────────────────────────────────────────────────────────────── */
const outDir = path.join(CONTENT, 'longform', month);
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'description_ja.txt'), filled.trimEnd() + '\n');
fs.writeFileSync(path.join(outDir, 'script_ja.md'), scriptMd);
fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify({
  month,
  generated_by: 'scripts/content/make_longform.mjs',
  kind: 'draft — the edit is done by a person',
  channel_param: CHANNEL,
  landing_cta: `https://slimfile.net${landing}?via=${CHANNEL}`,
  episodes: parts.map((p) => ({
    ep: p.topic.ep,
    title_ja: p.topic.title_ja,
    publish_on: p.topic.publish_on,
    article: blogUrl({ slug: slugFor(p.topic), channel: CHANNEL, epp: p.epp }),
    shorts_cut: fs.existsSync(path.join(CONTENT, `ep${p.epp}`, 'shorts.mp4')) ? `content/jp/ep${p.epp}/shorts.mp4` : null,
    post_written: !p.missing
  })),
  planned_chapters: chapters.map((c) => ({ at: mmss(c.at), label: c.label })),
  planned_length: mmss(totalSec),
  // Set by hand after upload. Starts false — a checklist that defaults to done
  // is not a checklist, and the Shorts cannot point at a video that is not up.
  posted: { youtube: false, url: null, related_video_set_on_shorts: false },
  warnings
}, null, 2) + '\n');

process.stdout.write(`${month}: ${parts.length} episode(s), planned ${mmss(totalSec)}\n`);
parts.forEach((p) => process.stdout.write(`  ep${p.epp}  ${p.missing ? '(post_ja.md missing)' : p.topic.title_ja}\n`));
process.stdout.write(`\nwritten to ${path.relative(REPO, outDir)}/\n`);
if (warnings.length) {
  process.stdout.write('\nwarnings:\n');
  warnings.forEach((w) => process.stdout.write('  - ' + w + '\n'));
}
