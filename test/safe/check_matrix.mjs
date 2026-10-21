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
 *   5. enforce that the fields JP_RULES names are the fields the JSON names,
 *   6. derive the LEGAL group per document from `legal_enforcement: true` and
 *      require set equality with JP_LEGAL — plus the invariant
 *      `verified:false ⇒ never legal_enforcement`. The old check only asked
 *      whether a field name appeared somewhere in the matrix, which let
 *      住民票コード (verified:false, no citation secured) sit under a banner
 *      asserting the recipient may not keep it (Codex 6b-10).
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
const matrixLegal = {};       // doc → Set(field) grounded in statute
function applyRule(docId, rule, where) {
  const token = LEVEL_TOKEN[rule.level];
  if (!token) { fail(where, `unknown level "${rule.level}"`); return; }
  if (!Array.isArray(rule.fields) || !rule.fields.length) { fail(where, 'rule has no `fields` (code field keys)'); return; }
  if (rule.verified === false && AUTOMATIC.has(token))
    fail(where, `verified:false but level "${rule.level}" is automatic — an unsourced rule may not delete pixels on its own`);
  if (rule.legal_enforcement === true) {
    if (rule.verified === false)
      fail(where, 'verified:false but legal_enforcement:true — a rule whose citation we could not secure may not assert a statutory restriction');
    matrixLegal[docId] = matrixLegal[docId] || new Set();
    for (const f of rule.fields) matrixLegal[docId].add(f);
  }
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
const legalSrc = slice('const JP_LEGAL = {', '\n};\n');
let JP_RULES, jpLevel, JP_LEGAL;
try {
  ({ JP_RULES, jpLevel, JP_LEGAL } =
    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL};`)());
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

/* ── 6. the legal group IS what the matrix grounds in statute, per document ──
   Set equality, not subset: a missing member silently drops a statutory band
   back under the category checkboxes (the Codex 4-6 failure), and an extra one
   asserts a restriction the matrix does not claim (the Codex 6b-10 failure). */
let legalPairs = 0;
for (const doc of new Set([...Object.keys(matrixLegal), ...Object.keys(JP_LEGAL)])) {
  const want = matrixLegal[doc] || new Set();
  const got = new Set(JP_LEGAL[doc] || []);
  if (!JP_LEGAL[doc]) fail(`JP_LEGAL.${doc}`, 'document missing from JP_LEGAL (write [] if it has no statutory field)');
  for (const f of got) if (!want.has(f)) fail(`JP_LEGAL.${doc}.${f}`, 'in the legal group but the matrix does not mark it legal_enforcement:true');
  for (const f of want) if (!got.has(f)) fail(`JP_LEGAL.${doc}.${f}`, 'matrix says legal_enforcement:true but the code leaves it to the category checkboxes');
  legalPairs += new Set([...want, ...got]).size;
}
// Same reason as `compared`: zero comparisons print the same green as many.
if (legalPairs < 8) fail('coverage', `only ${legalPairs} legal (doc, field) pairs compared — the extraction is probably broken`);

if (problems.length) {
  console.log(`\n✗ legal matrix ↔ code: ${problems.length} disagreement(s) over ${compared} triples\n`);
  for (const p of problems) console.log('   ' + p);
  console.log('');
  process.exit(1);
}
console.log(`✅ legal matrix ↔ code: ${compared} (doc, field, purpose) triples identical, ${legalPairs} legal pairs identical, verified:false⇒no-auto/no-legal holds`);
