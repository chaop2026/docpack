/*
 * Loader for content/jp/guard_rules.json — the single source for the writing
 * rules both this pipeline and the server's JpContentGuard enforce.
 *
 * The rules used to be JS constants inside make_episode.mjs, which meant the
 * server could not see them and the two halves of the project could drift
 * without anything saying so. They now live in JSON; this file is the only
 * place that turns them into RegExps on the JavaScript side.
 *
 * Every pattern is compiled eagerly. A rule whose regex is unportable (Ruby-only
 * syntax, say) would otherwise just never match — a guard that silently stops
 * guarding looks exactly like a guard that found nothing.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
export const RULES_FILE = path.join(REPO, 'content', 'jp', 'guard_rules.json');

const compile = (rule, where) => {
  let flags = '';
  if (rule.ignorecase) flags += 'i';
  if (rule.dotall) flags += 's';
  try {
    return new RegExp(rule.re, flags);
  } catch (e) {
    throw new Error(`guard_rules.json: ${where} «${rule.id || rule.re}» does not compile as a JS RegExp: ${e.message}`);
  }
};

const raw = JSON.parse(fs.readFileSync(RULES_FILE, 'utf8'));

export const RULES = {
  mustLine: raw.must_line.ja,
  mustSentence: raw.must_line.ja_sentence,
  mustLineEn: raw.must_line.en,
  limits: raw.limits,
  forbidden: raw.forbidden.map((f) => ({ id: f.id, re: compile(f, 'forbidden'), why: f.why })),
  legalClaim: {
    patterns: raw.legal_claim.claim_patterns.map((p) => ({ id: p.id, re: compile(p, 'legal_claim'), why: p.why })),
    sourceUrl: compile({ re: raw.legal_claim.source_url_re, id: 'source_url_re' }, 'legal_claim'),
    confirmedOn: compile({ re: raw.legal_claim.confirmed_on_re, id: 'confirmed_on_re' }, 'legal_claim'),
    why: raw.legal_claim.why
  },
  faqHeading: raw.required_sections_ja.faq_heading
};

if (!RULES.forbidden.length) {
  throw new Error('guard_rules.json carries no forbidden patterns — refusing to run with an empty guard');
}

/*
 * twitter-text weighted length.
 *
 * X does not count characters; it counts weight. Latin, digits and ASCII
 * punctuation weigh 1, everything else (so: all Japanese) weighs 2, and a URL
 * is a flat 23 whatever its length. v3 described 140 as «X's limit», which is
 * our editorial limit — the platform's is 280 weighted. Both numbers live in
 * guard_rules.json so a report can say which one it is failing.
 *
 * Emoji are counted per grapheme cluster rather than per code point: a ZWJ
 * sequence such as 👨‍👩‍👧 is one visible character to the author and five code
 * points to naive iteration. Intl.Segmenter does the clustering.
 */
const URL_RE = /https?:\/\/\S+/g;
const URL_WEIGHT = 23;

// twitter-text's default config: these ranges weigh 1, everything else 2.
const LIGHT_RANGES = [
  [0x0000, 0x10ff], [0x2000, 0x200d], [0x2010, 0x201f], [0x2032, 0x2037]
];
const isLight = (cp) => LIGHT_RANGES.some(([lo, hi]) => cp >= lo && cp <= hi);

const segmenter = typeof Intl !== 'undefined' && Intl.Segmenter
  ? new Intl.Segmenter('ja', { granularity: 'grapheme' })
  : null;

const graphemes = (s) => (segmenter
  ? Array.from(segmenter.segment(s), (seg) => seg.segment)
  : Array.from(s));

export function weightedLength(text) {
  let total = 0;
  let rest = text;

  // URLs first, so their internal characters never get weighed individually.
  const urls = rest.match(URL_RE) || [];
  total += urls.length * URL_WEIGHT;
  rest = rest.replace(URL_RE, '');

  for (const g of graphemes(rest)) {
    // A cluster is 2 unless it is a single light code point. Multi-code-point
    // clusters (emoji sequences, combining marks) are one visible character and
    // weigh 2 — not 2 per code point.
    const cps = Array.from(g);
    total += (cps.length === 1 && isLight(cps[0].codePointAt(0))) ? 1 : 2;
  }
  return total;
}

/*
 * Run the rules over a named corpus: [[surfaceName, text], ...].
 * Returns a flat array of human-readable violation strings.
 *
 * The corpus is NAMED rather than concatenated on purpose — see the comment in
 * make_episode.mjs. A violation has to say which file it is in, and adding a
 * surface has to mean adding a line.
 */
export function runForbidden(corpus) {
  const out = [];
  for (const [where, text] of corpus) {
    for (const f of RULES.forbidden) {
      const m = String(text).match(f.re);
      if (m) out.push(`${where}: 「${m[0].slice(0, 40)}」 — ${f.why} [${f.id}]`);
    }
  }
  return out;
}

/*
 * Conditional source requirement. Returns [] when the text makes no legal claim.
 * `article` is everything a reader of this piece can see — the claim and its
 * source do not have to be in the same paragraph, but they do have to be in the
 * same published article.
 */
export function runLegalClaim(where, article) {
  const hits = RULES.legalClaim.patterns.filter((p) => p.re.test(article));
  if (!hits.length) return [];

  const hasUrl = RULES.legalClaim.sourceUrl.test(article);
  const hasDate = RULES.legalClaim.confirmedOn.test(article);
  if (hasUrl && hasDate) return [];

  const missing = [ !hasUrl && '*.go.jp の原文URL', !hasDate && '「確認日: YYYY-MM-DD」' ].filter(Boolean);
  return [ `${where}: 法的主張 (${hits.map((h) => h.id).join(', ')}) があるのに ${missing.join(' と ')} がない — ${RULES.legalClaim.why}` ];
}

/*
 * The required line, checked the way the rule is written: its own line, ending
 * in 「。」. A line-insensitive `includes` would pass on a sentence that merely
 * contains the words mid-paragraph, which is not the standing instruction the
 * strategy asks for.
 */
export function mustLineViolations(where, text) {
  const lines = String(text).split(/\r?\n/).map((l) => l.trim());
  if (lines.some((l) => l.replace(/\*\*/g, '') === RULES.mustSentence)) return [];
  if (String(text).includes(RULES.mustLine)) {
    return [ `${where}: 「${RULES.mustSentence}」 が独立した行になっていない(または「。」で終わっていない)` ];
  }
  return [ `${where}: 必須文 「${RULES.mustSentence}」 がない` ];
}
