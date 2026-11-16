#!/usr/bin/env node
/*
 * video-qa — checks a video episode's ARTIFACTS, nothing else (2026-11-16).
 *
 *   node scripts/content/qa_video.mjs 1 2026-11
 *   node scripts/content/qa_video.mjs 1              # skip the long-form half
 *
 * Run before uploading, before marking an episode done, and before asking for
 * approval. It does not look at how anything was made — only at the files on
 * disk and at the rules in content/jp/guard_rules.json. Knowing the intent is
 * what produces "well, given the circumstances"; this has no circumstances.
 *
 * ── Why it is a committed script and not a checklist ───────────────────────
 *
 * The same six checks were being rebuilt by hand every round, and a check
 * rebuilt each time is a check that is slightly different each time. This
 * repository learned that with script/canonical_sweep.rb — and learned the
 * sequel too: the moment a verification script is committed it becomes
 * something that can itself be wrong. Two of this one's own bugs are recorded
 * in the comments below. Both were found by running it, and both would have
 * produced a confident green.
 *
 * 🔴 Every check COUNTS what it looked at, and zero is a failure. An empty
 * list satisfies every assertion made about its members.
 *
 * Exit 0 = pass, 1 = hold. 「대체로 괜찮다」 is not a verdict.
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const { RULES, runForbidden, mustLineViolations } =
  await import(pathToFileURL(path.join(REPO, 'scripts', 'content', 'guard_rules.mjs')).href);

const EP = Number(process.argv[2] || 1);
const EPP = String(EP).padStart(2, '0');
const EPDIR = `content/jp/ep${EPP}`;
// The long-form half is skipped when no month is given. The surface count in
// the output drops with it, so a smaller run is visible rather than silent.
const MONTH = /^\d{4}-\d{2}$/.test(process.argv[3] || '') ? process.argv[3] : null;

const read = (p) => fs.readFileSync(path.join(REPO, p), 'utf8');
const exists = (p) => fs.existsSync(path.join(REPO, p));

/* The PUBLISHED text of a channel template is the ``` block, not the file.
 * Everything outside it is a note — including notes that spell out forbidden
 * words in order to forbid them. Scanning whole files reported four violations
 * that were all commentary; the SAME run caught two real ones (a required line
 * that was not on its own line, twice), so the scope was narrowed rather than
 * the check weakened. content/jp/channel/README.md states the rule once and
 * all three templates follow it. */
const fenced = (p) => {
  const m = read(p).match(/```\n([\s\S]*?)```/);
  if (!m) throw new Error(`${p} has no \`\`\` block — that block IS the published text`);
  return m[1];
};

let fail = 0;
const say = (s) => process.stdout.write(s + '\n');
const bad = (s) => { say('    🔴 ' + s); fail++; };

say(`video-qa — ep${EPP}${MONTH ? ` + longform ${MONTH}` : ''}\n`);

/* ── ① guard over every published surface ─────────────────────────────────── */
/* Enumerated, not globbed: the number of surfaces CHECKED has to be
 * comparable with the number of surfaces PUBLISHED. 「검사 범위 < 게시 범위」 is
 * this project's repeat defect — a guard once checked five tweets and six
 * were posted, and the build reported no violations. */
const thumbs = exists(`${EPDIR}/thumbnails.json`) ? JSON.parse(read(`${EPDIR}/thumbnails.json`)) : null;
const shortJson = exists(`${EPDIR}/short_ja.json`) ? JSON.parse(read(`${EPDIR}/short_ja.json`)) : null;

const surfaces = [];
const add = (name, text) => { if (text != null && String(text).trim()) surfaces.push([ name, String(text) ]); };

add(`ep${EPP}/shorts_title_ja.txt`, exists(`${EPDIR}/shorts_title_ja.txt`) && read(`${EPDIR}/shorts_title_ja.txt`));
add(`ep${EPP}/shorts_desc_ja.txt`, exists(`${EPDIR}/shorts_desc_ja.txt`) && read(`${EPDIR}/shorts_desc_ja.txt`));
if (thumbs) {
  for (const v of [ ...new Set(thumbs.files.map((f) => f.variant)) ]) {
    add(`ep${EPP} thumbnail text (${v})`,
      thumbs.files.filter((f) => f.variant === v).map((f) => (f.headline || []).join(' ')).join(' '));
  }
}
if (shortJson) add(`ep${EPP} shorts rendered segments`, JSON.stringify(shortJson.rendered_segments || {}));
add('channel/channel_about_ja.md (published block)', fenced('content/jp/channel/channel_about_ja.md'));
add('channel/pinned_comment_ja.md (published block)', fenced('content/jp/channel/pinned_comment_ja.md'));
add('channel/upload_default_description_ja.md (template block)', fenced('content/jp/channel/upload_default_description_ja.md'));
if (MONTH) {
  add(`longform ${MONTH} description`, exists(`content/jp/longform/${MONTH}/description_ja.txt`) && read(`content/jp/longform/${MONTH}/description_ja.txt`));
  add(`longform ${MONTH} script`, exists(`content/jp/longform/${MONTH}/script_ja.md`) && read(`content/jp/longform/${MONTH}/script_ja.md`));
}

const gv = runForbidden(surfaces);
say(`① guard      : ${gv.length} violation(s) — ${surfaces.length} surface(s) × ${RULES.forbidden.length} rules = ${surfaces.length * RULES.forbidden.length} checks`);
gv.forEach((v) => bad(v));
if (!surfaces.length) bad('0 surfaces checked — the guard result is vacuous');

// The required line, only where a reader actually sees it.
const mustWhere = surfaces.filter(([ n ]) =>
  /shorts_desc|longform .* description|channel_about|pinned_comment/.test(n));
const mv = mustWhere.flatMap(([ w, t ]) => mustLineViolations(w, t));
say(`   must-line : ${mv.length} violation(s) over ${mustWhere.length} surface(s)`);
mv.forEach((v) => bad(v));
if (!mustWhere.length) bad('0 surfaces carry the required-line rule — vacuous');

/* ── ② specs, read from the files themselves ──────────────────────────────── */
let specChecks = 0;
if (exists(`${EPDIR}/shorts.mp4`)) {
  const probe = spawnSync('ffprobe', [ '-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height:format=duration', '-of', 'json',
    path.join(REPO, `${EPDIR}/shorts.mp4`) ], { encoding: 'utf8' });
  if (probe.status !== 0) bad(`ffprobe failed on shorts.mp4: ${(probe.stderr || '').slice(-120)}`);
  else {
    const m = JSON.parse(probe.stdout);
    const vs = m.streams[0], dur = Number(m.format.duration);
    const ok = vs.width === 1080 && vs.height === 1920 && dur > 0 && dur <= 30.5;
    say(`② specs      : shorts.mp4 ${vs.width}×${vs.height} ${dur.toFixed(2)}s  ${ok ? 'OK' : 'FAIL'}`);
    if (!ok) bad('shorts.mp4 is not 1080×1920 within 30s');
    specChecks++;
  }
} else {
  say('② specs      : no shorts.mp4');
  bad(`${EPDIR}/shorts.mp4 does not exist`);
}

// PNG size from the IHDR — the file's own account, not what we asked the
// browser for. Those two can disagree, which is the reason to look.
const pngSize = (p) => {
  const h = Buffer.alloc(24);
  const fd = fs.openSync(path.join(REPO, p), 'r');
  try { fs.readSync(fd, h, 0, 24, 0); } finally { fs.closeSync(fd); }
  return { w: h.readUInt32BE(16), h: h.readUInt32BE(20) };
};
const wanted = [
  [ 'thumb_short_a.png', 1080, 1920 ], [ 'thumb_short_b.png', 1080, 1920 ],
  [ 'thumb_long_a.png', 1280, 720 ], [ 'thumb_long_b.png', 1280, 720 ], [ 'thumb_long_c.png', 1280, 720 ]
];
let tOk = 0, tSeen = 0;
for (const [ name, w, h ] of wanted) {
  if (!exists(`${EPDIR}/${name}`)) { bad(`${EPDIR}/${name} does not exist`); continue; }
  tSeen++; specChecks++;
  const s = pngSize(`${EPDIR}/${name}`);
  if (s.w === w && s.h === h) tOk++; else bad(`${name} is ${s.w}×${s.h}, want ${w}×${h}`);
}
say(`             : thumbnails ${tOk}/${tSeen} at the declared size`);
if (!tSeen) bad('0 thumbnails checked — vacuous');

// Safe area: a measurement of the RENDERED boxes, recorded at build time.
if (thumbs) {
  const outside = thumbs.files.reduce((n, f) => n + (f.outside || 0), 0);
  say(`             : safe-area violations ${outside} over ${thumbs.files.length} file(s)`);
  if (outside) bad('text leaves the Shorts safe area — the platform UI will cover it');
  if (!thumbs.files.length) bad('thumbnails.json lists 0 files — vacuous');
} else bad(`${EPDIR}/thumbnails.json does not exist`);

/* ── ③ link placement — the rule this channel gets wrong ──────────────────── */
/* Shorts descriptions and Shorts comments are NOT clickable (2026-11-01). A
 * URL there converts at zero, and the only symptom is that a URL is present —
 * from outside it looks exactly like a working funnel. */
const URL_RE = /https?:\/\/\S+/g;
const unclickable = [ [ 'pinned_comment_ja.md (published block)', fenced('content/jp/channel/pinned_comment_ja.md') ] ];
if (shortJson?.end_card?.line) unclickable.push([ 'shorts end card text', shortJson.end_card.line ]);
let linkFail = 0;
for (const [ w, t ] of unclickable) {
  const u = t.match(URL_RE);
  if (u) { bad(`${w} contains ${u.length} URL(s) on an UNCLICKABLE surface`); linkFail++; }
}
say(`③ link rules : ${linkFail} violation(s) over ${unclickable.length} unclickable surface(s)`);
if (!unclickable.length) bad('0 unclickable surfaces checked — vacuous');

/* ── the shorts description: reported every run, decided by a person ───────
 *
 * `shorts_description` IS in config/video_team.yml's unclickable list, and the
 * video-qa contract says a URL on an unclickable surface is a defect. The
 * description nonetheless carries two, and cross-review (2026-11-16) called
 * that out correctly: a rule declared and not enforced is not a rule.
 *
 * It is NOT silently exempted and it is NOT quietly deleted either, because
 * the URL there is an older, TESTED decision, not an oversight:
 * test/integration/jp_shorts_test.rb:111 asserts every episode's description
 * carries a ?via=youtube&ep= link (S10). Reversing it changes eight committed
 * descriptions, one already-published video's text, and that test.
 *
 * So the count is PRINTED on every run and the verdict is left alone. An
 * open decision that announces itself each time is the honest state; the
 * alternatives are a check that lies and a check that always says 보류. */
if (exists(`${EPDIR}/shorts_desc_ja.txt`)) {
  const n = (read(`${EPDIR}/shorts_desc_ja.txt`).match(URL_RE) || []).length;
  say(`             : ⓘ shorts_desc_ja.txt carries ${n} URL(s) — that surface is NOT clickable.`);
  say('               Kept by the S10 decision that jp_shorts_test.rb:111 pins. OPEN — see');
  say('               docs/jp/video_qa_ep01.md 「결정 대기」. Not counted against the verdict.');
}

const endOk = shortJson?.end_card?.line === 'プロフィールのリンクから' && shortJson.end_card.from;
say(`             : end card = ${endOk
  ? `${shortJson.end_card.from} + 「${shortJson.end_card.line}」 @${shortJson.end_card.starts_at_sec}s`
  : 'MISSING'}`);
if (!endOk) bad('no end card, or it does not send the viewer to the profile link');

/* Every `via=` we publish must be a value the server will store. An unknown
 * one makes SafeEvent.sanitize return nil, which discards the WHOLE event —
 * and sendBeacon never reads the response, so the loss is invisible both ends. */
const viaVals = new Set();
const viaSources = [ `${EPDIR}/shorts_desc_ja.txt`, 'content/jp/channel/profile_links.md',
  'content/jp/channel/upload_default_description_ja.md' ];
if (MONTH) viaSources.push(`content/jp/longform/${MONTH}/description_ja.txt`);
for (const p of viaSources) {
  if (!exists(p)) continue;
  for (const m of read(p).matchAll(/[?&]via=([a-z_]+)/g)) viaVals.add(m[1]);
}
const allowed = read('app/models/safe_event.rb').match(/"via"\s*=>\s*%w\[([^\]]+)\]/)[1].split(/\s+/).filter(Boolean);
const badVia = [ ...viaVals ].filter((v) => !allowed.includes(v));
say(`             : via values {${[ ...viaVals ].join(', ')}} — ${badVia.length} the server would reject`);
if (!viaVals.size) bad('0 via values found — this check is vacuous');
badVia.forEach((v) => bad(`?via=${v} is not in SafeEvent::VALUES["via"] — the event would be discarded whole`));

if (MONTH && exists(`content/jp/longform/${MONTH}/description_ja.txt`)) {
  // The long-form CTA covers four episodes, so it must not claim one.
  const cta = read(`content/jp/longform/${MONTH}/description_ja.txt`).split('\n')[1] || '';
  if (!/via=yt_long/.test(cta) || /ep=/.test(cta)) bad(`long-form CTA line is wrong: ${cta}`);
  else say('             : long-form CTA = via=yt_long, no ep  OK');
}

/* ── ③b the declared config vs the values the code actually uses ─────────── */
/*
 * config/video_team.yml declares the channel parameters; the generators hard-
 * code them. Cross-review (2026-11-16) called that split out: a config nothing
 * reads is a config that can say anything.
 *
 * The split is deliberate — a YAML loader that fell back to a default would
 * publish links with the wrong `via`, and the server discards an unknown value
 * as a WHOLE event while sendBeacon never reads the response. Hardcoding plus
 * this comparison moves that failure to build time instead.
 *
 * Read with a regex rather than a YAML parser: two scalar keys do not justify
 * a dependency, and a parse failure here must be loud, not a nil that compares
 * equal to nothing.
 */
const cfg = read('config/video_team.yml');
const declared = {
  shorts: (cfg.match(/^\s*shorts_channel:\s*(\S+)/m) || [])[1],
  longform: (cfg.match(/^\s*longform_channel:\s*(\S+)/m) || [])[1],
  param: (cfg.match(/^\s*param:\s*(\S+)/m) || [])[1]
};
const used = {
  shorts: /channel: 'youtube'/.test(read('scripts/content/lib/shorts.mjs')) ? 'youtube' : null,
  longform: (read('scripts/content/make_longform.mjs').match(/const CHANNEL = '([a-z_]+)'/) || [])[1],
  param: /\?via=\$\{channel\}/.test(read('scripts/content/lib/episode.mjs')) ? 'via' : null
};
let cfgMismatch = 0, cfgChecked = 0;
for (const k of Object.keys(declared)) {
  cfgChecked++;
  if (!declared[k]) { bad(`video_team.yml declares no ${k} — cannot compare`); cfgMismatch++; continue; }
  if (!used[k]) { bad(`could not find the ${k} value in the generators — the comparison is vacuous`); cfgMismatch++; continue; }
  if (declared[k] !== used[k]) { bad(`${k}: config says "${declared[k]}", the code uses "${used[k]}"`); cfgMismatch++; }
}
say(`③b config    : ${cfgMismatch} mismatch(es) over ${cfgChecked} declared value(s) `
  + `{${Object.entries(declared).map(([ k, v ]) => `${k}=${v}`).join(', ')}}`);
if (!cfgChecked) bad('0 config values compared — vacuous');

/* The four agent definitions live OUTSIDE this repository (~/.claude/agents/),
 * so a fresh clone has the config and the docs but not the contract they
 * describe. Checked for existence rather than content: the repo cannot own
 * them without having two copies, but it can refuse to pretend they are here. */
const AGENTS = [ 'video-story', 'video-production', 'video-thumbnail', 'video-qa' ];
const agentDir = path.join(process.env.HOME || '', '.claude', 'agents');
const missingAgents = AGENTS.filter((a) => !fs.existsSync(path.join(agentDir, `${a}.md`)));
say(`             : agent definitions ${AGENTS.length - missingAgents.length}/${AGENTS.length} present in ~/.claude/agents/`);
missingAgents.forEach((a) => bad(`~/.claude/agents/${a}.md is missing — see docs/jp/video_team_reuse.md`));

/* ── ④ boundary ───────────────────────────────────────────────────────────── */
const st = spawnSync('git', [ 'status', '--short' ], { cwd: REPO, encoding: 'utf8' })
  .stdout.trim().split('\n').filter(Boolean);
const touchedForbidden = st.filter((l) => /config\/deploy\.yml|\.kamal\/|\.env/.test(l));
say(`④ boundary   : ${st.length} changed path(s); deploy/secret files touched: ${touchedForbidden.length}`);
touchedForbidden.forEach((l) => bad(l.trim()));

/* ── ⑤ public exposure, asked of the CHANGE ───────────────────────────────── */
/* Scanning whole files reported public/safe/jp/jp.js, whose contact address
 * has been in HEAD since long before this work and is a deliberate public
 * contact on a landing page. "The repo contains an email" and "this change
 * added one" are different questions; only the second is a session's to
 * answer. Untracked files are scanned whole — all of them are new. */
const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
const SECRET = /(api[_-]?key|secret|token|password)\s*[:=]\s*['"][^'"]{8,}/gi;
const textish = (p) => /\.(md|json|mjs|js|rb|yml|txt|html|css)$/.test(p);

/* Parsed, not sliced at a fixed offset. `git status --short` pads the status
 * field and assuming three characters ate the first letter of every path —
 * "app/models/…" became "pp/models/…". It failed loudly as ENOENT; a path that
 * merely did not match a filter would have scanned nothing and said so in
 * green. */
const pathOf = (l) => l.trim().replace(/^[A-Z?!]{1,2}\s+/, '');
const tracked = st.filter((l) => /^M/.test(l.trim())).map(pathOf).filter(textish);
const untrackedFiles = st.filter((l) => l.trim().startsWith('??')).map(pathOf).flatMap(function expand(p) {
  const full = path.join(REPO, p);
  if (!fs.existsSync(full)) return [];
  if (!fs.statSync(full).isDirectory()) return [ p ];
  return fs.readdirSync(full).flatMap((c) => expand(path.join(p, c)));
}).filter(textish);

let exposed = 0, scanned = 0, preexisting = 0;
for (const p of tracked) {
  scanned++;
  const diff = spawnSync('git', [ 'diff', '-U0', '--', p ], { cwd: REPO, encoding: 'utf8' }).stdout;
  const added = diff.split('\n').filter((l) => l.startsWith('+') && !l.startsWith('+++')).join('\n');
  if ((read(p).match(EMAIL) || []).length && !(added.match(EMAIL) || []).length) preexisting++;
  const e = added.match(EMAIL) || [], s = added.match(SECRET) || [];
  if (e.length) { bad(`${p}: ${e.length} email-shaped string(s) ADDED by this change`); exposed++; }
  if (s.length) { bad(`${p}: ${s.length} secret-shaped assignment(s) ADDED (value NOT printed)`); exposed++; }
}
for (const p of untrackedFiles) {
  scanned++;
  const t = read(p);
  const e = t.match(EMAIL) || [], s = t.match(SECRET) || [];
  if (e.length) { bad(`${p}: ${e.length} email-shaped string(s) in a NEW file`); exposed++; }
  if (s.length) { bad(`${p}: ${s.length} secret-shaped assignment(s) (value NOT printed)`); exposed++; }
}
/* The claim is bounded on purpose. This finds email addresses and
 * `key/secret/token/password = "…"` assignments, and nothing else — not PEM
 * blocks, not bare Bearer tokens, not AWS/GitHub/Slack key shapes, not
 * unquoted YAML values, not credentials inside a URL. Cross-review
 * (2026-11-16) was right that the earlier wording read like a secret scan.
 * "0 found by these two patterns" is a weaker statement than "no secrets",
 * and printing the weaker one is the point. */
say(`⑤ exposure   : ${exposed} introduced over ${scanned} text file(s) `
  + `(${tracked.length} modified + ${untrackedFiles.length} new); `
  + `${preexisting} carry a pre-existing address, untouched`);
say('               (patterns: email-shaped strings + quoted key/secret/token/password '
  + 'assignments only — NOT a general secret scanner)');
if (!scanned) bad('0 files scanned — vacuous');

/* ── ⑥ vacuity ────────────────────────────────────────────────────────────── */
const counts = {
  surfaces: surfaces.length, spec_checks: specChecks, thumbnails: tSeen,
  via_values: viaVals.size, unclickable_surfaces: unclickable.length, files_scanned: scanned
};
const zero = Object.entries(counts).filter(([ , v ]) => !v).map(([ k ]) => k);
say(`⑥ vacuity    : ${JSON.stringify(counts)}${zero.length ? ' — ZERO: ' + zero.join(', ') : ' — all > 0'}`);
zero.forEach((k) => bad(`${k} is 0 — every assertion about its members passed by default`));

say('');
say(fail ? `판정: 보류 — ${fail} 항목` : '판정: 통과 — 모든 항목 ✅');
process.exit(fail ? 1 : 0);
