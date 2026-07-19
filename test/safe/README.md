# SafeFile golden-fixture tests

Automated regression gate for the PII detection/redaction pipeline in
`public/safe/index.html`. Instead of fixing symptoms one document at a time,
this encodes the **expected result** for a set of trap documents as a spec, then
verifies the *live* page against it headlessly. **Run it after every change to
the SafeFile pipeline and keep it green.**

## What it checks

For each fixture, `specs.json` declares:

| Field | Meaning |
|-------|---------|
| `must_mask` | value MUST end up geometrically covered by a mask rect |
| `must_not_mask` | value must NEVER be covered (schools, orgs, countries, place names) |
| `never_candidate` | value must not even be *proposed* as a review candidate (e.g. `Korea`) |
| `should_candidate` | value must surface as a visible candidate (top name, address) |
| `phone_format` | partial phone mask must preserve the original string format |
| `name_bar` | a large-name black bar hugs the glyphs (no ink exposed, not oversized) |
| `min_auto` | regression floor on the auto-detected entity count |
| `ai_inject` | adversarial AI labels are neutralised in `addEntities` (no live API needed) |

Plus: every PDF output is re-parsed and asserted to have **0 extractable
characters** (no text-layer leak).

The `ai_inject` block reproduces the real-document false positives (an AI
labelling `Maharaja Agrasen College` / `Concern India Foundation` as a person's
name, or `Korea` / `Indian` as an address) **without** calling the paid AI
endpoint — it feeds those exact labels straight into the detection layer and
asserts they are demoted to visible or dropped.

## Fixtures (synthetic — no real personal data)

`generate_fixtures.py` (pymupdf + Pillow) writes to `testdocs/` (git-ignored):

- `1_text` `2_scanned` `4_table` `5_multipage` — Korean base docs (regression)
- `3_photo.jpg` — OCR path
- `6_resume_light.pdf` — single-column Indian résumé
- `7_resume_dark.pdf` — 2-column light/dark Indian résumé reproducing every trap:
  48pt serif name, `+91` phone, wrapping address, standalone `Korea`,
  `(Koreaz Contest)`, multiple schools, a body-prose org (`Concern India
  Foundation`), and a dark-green column (contrast/background test).

## Running

```bash
cd test/safe
npm install                 # playwright (chrome channel)
python3 generate_fixtures.py   # regenerate testdocs/ (needs pymupdf, pillow)
node run.mjs                # exit 0 = all pass; --only 7_resume_dark.pdf to focus
```

Requires Google Chrome installed (Playwright launches it via `channel:'chrome'`).
A JSON report is written to `out/report.json`.
