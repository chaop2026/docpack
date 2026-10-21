#!/usr/bin/env node
/*
 * Legal matrix ↔ code cross-check.
 *
 * jp_legal_matrix_alpha4.json is the 정본 (single source of truth). The page is a
 * single static HTML file with no build step, so JP_RULES in public/safe/index.html
 * is a hand-written mirror of it. A second hand-written table is exactly how the
 * two drift apart (Codex 4-1 found seven disagreements), so this file makes the
 * drift a test failure instead of a reading exercise:
 *
 *   1. derive (doc, field, purpose) → level from the JSON,
 *   2. read JP_RULES + jpLevel out of index.html and evaluate them,
 *   3. compare EVERY (doc, field, purpose) triple in either table,
 *   4. enforce the invariant `verified:false ⇒ never auto/gate` on the JSON,
 *   5. enforce that the fields JP_RULES names are the fields the JSON names.
 *
 * run.mjs calls this first, so the golden cannot pass while the tables disagree.
 * Usage: node check_matrix.mjs   (exit 0 = identical)
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..', '..');
const MATRIX = path.join(__dirname, 'fixtures', 'jp', 'jp_legal_matrix_alpha4.json');
const PAGE = path.join(REPO, 'public', 'safe', 'index.html');

const LEVEL_TOKEN = { auto: 'auto', auto_with_purpose_gate: 'gate', recommend: 'recommend', optional: 'optional', keep: 'keep' };
const AUTOMATIC = new Set(['auto', 'gate']);

const problems = [];
const fail = (what, msg) => problems.push(`${what}: ${msg}`);

/* ── 1. the 정본 → a (doc, field, purpose) table ── */
const M = JSON.parse(fs.readFileSync(MATRIX, 'utf8'));
const PURPOSES = Object.keys(M.purposes);
const matrix = {};            // doc → field → purpose → level
const matrixFields = {};      // doc → Set(field)
function applyRule(docId, rule, where) {
  const token = LEVEL_TOKEN[rule.level];
  if (!token) { fail(where, `unknown level "${rule.level}"`); return; }
  if (!Array.isArray(rule.fields) || !rule.fields.length) { fail(where, 'rule has no `fields` (code field keys)'); return; }
  if (rule.verified === false && AUTOMATIC.has(token))
    fail(where, `verified:false but level "${rule.level}" is automatic — an unsourced rule may not delete pixels on its own`);
  const seen = {};
  const put = (purpose, level) => {
    if (!PURPOSES.includes(purpose)) { fail(where, `unknown purpose "${purpose}"`); return; }
    if (seen[purpose]) { fail(where, `purpose "${purpose}" appears twice (${seen[purpose]} and ${level})`); return; }
    seen[purpose] = level;
    for (const f of rule.fields) {
      matrix[docId] = matrix[docId] || {};
      matrix[docId][f] = matrix[docId][f] || {};
      matrixFields[docId] = matrixFields[docId] || new Set();
      matrixFields[docId].add(f);
      const prev = matrix[docId][f][purpose];
      if (prev && prev !== level) fail(`${docId}.${f}[${purpose}]`, `two rules disagree: ${prev} vs ${level}`);
      matrix[docId][f][purpose] = level;
    }
  };
  for (const p of (rule.must_keep_when || [])) put(p, 'keep');
  for (const p of (rule.mask_when || [])) put(p, token);
  for (const p of (rule.optional_when || [])) put(p, 'optional');
}
for (const doc of M.documents) for (const r of doc.rules) applyRule(doc.id, r, `${doc.id} 「${r.field}」`);
// general_jp applies to every listed document.
const G = M.general_jp || { applies_to: [], rules: [] };
for (const docId of G.applies_to) for (const r of G.rules) applyRule(docId, r, `general_jp→${docId} 「${r.field}」`);

/* ── 2. the code → JP_RULES + jpLevel ── */
const src = fs.readFileSync(PAGE, 'utf8');
function slice(startMarker, endMarker) {
  const a = src.indexOf(startMarker);
  if (a < 0) throw new Error(`cannot find ${startMarker} in ${PAGE}`);
  const b = src.indexOf(endMarker, a);
  if (b < 0) throw new Error(`cannot find ${endMarker} after ${startMarker}`);
  return src.slice(a, b + endMarker.length);
}
// Everything from the purpose shorthands through the end of JP_RULES, then jpLevel.
const rulesSrc = slice('const P_NOT_MYNUM =', '\n};\n');
const levelSrc = slice('function jpLevel(', '\n}\n');
const legalSrc = slice('const JP_LEGAL_FIELDS =', ']);');
let JP_RULES, jpLevel, JP_LEGAL_FIELDS;
try {
  ({ JP_RULES, jpLevel, JP_LEGAL_FIELDS } =
    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL_FIELDS};`)());
} catch (e) {
  console.error('could not evaluate JP_RULES / jpLevel out of index.html:', e.message);
  process.exit(2);
}

/* ── 3. compare every triple in EITHER table ── */
let compared = 0;
const docs = new Set([...Object.keys(matrix), ...Object.keys(JP_RULES)]);
for (const doc of docs) {
  const mf = matrixFields[doc] || new Set();
  const cf = new Set(Object.keys(JP_RULES[doc] || {}));
  for (const f of cf) if (!mf.has(f)) fail(`${doc}.${f}`, 'in JP_RULES but not in the legal matrix');
  for (const f of mf) if (!cf.has(f)) fail(`${doc}.${f}`, 'in the legal matrix but not in JP_RULES');
  for (const f of new Set([...mf, ...cf])) {
    for (const p of PURPOSES) {
      const want = ((matrix[doc] || {})[f] || {})[p] || null;
      const got = (JP_RULES[doc] && JP_RULES[doc][f]) ? jpLevel(doc, f, p) : null;
      compared++;
      if (want !== got) fail(`${doc}.${f}[${p}]`, `matrix says ${want || 'null (not offered)'}, code says ${got || 'null (not offered)'}`);
    }
  }
}
// A triple must have been checked. A comparison loop that silently ran zero
// times prints the same green as one that checked two hundred.
if (compared < 100) fail('coverage', `only ${compared} (doc, field, purpose) triples compared — the extraction is probably broken`);

/* ── 4/5. the legal group must be a subset of what the matrix grounds in statute ── */
for (const f of JP_LEGAL_FIELDS) {
  const inSome = Object.keys(matrix).some(d => matrix[d][f]);
  if (!inSome) fail(`JP_LEGAL_FIELDS.${f}`, 'not a field the legal matrix knows');
}

if (problems.length) {
  console.log(`\n✗ legal matrix ↔ code: ${problems.length} disagreement(s) over ${compared} triples\n`);
  for (const p of problems) console.log('   ' + p);
  console.log('');
  process.exit(1);
}
console.log(`✅ legal matrix ↔ code: ${compared} (doc, field, purpose) triples identical, verified:false⇒no-auto holds`);
