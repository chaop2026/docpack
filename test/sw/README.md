# Service-worker offline-resilience test

Fault-injection harness for `public/safe/sw.js`. It answers one question:

> when a service-worker update lands while the network is failing, does a
> returning visitor keep the offline app they already had?

Before 2026-09-17 the answer was **no**, and nothing caught it. `install`
wrapped every precache in `.catch(() => null)`, so a failed `/safe/` fetch still
counted as a successful install; `skipWaiting()` handed over to the new worker;
and `activate` then deleted the previous version's caches. The visitor was left
with neither shell. The failure is invisible from the outside — the update
*reports success* — which is why it needs an explicit test.

## What it does

Serves `public/safe/` from a small Node server with two injectable faults:

| Fault | Effect |
|---|---|
| `state.failShell` | `/safe/` answers **503** — a transient network failure |
| `state.swVersion` | substituted into `sw.js`'s `__SW_BUILD__` token, so the browser sees a genuinely new worker |

Then drives real Chrome through three phases:

1. **Healthy install** — v1 caches the shell.
2. **Update while `/safe/` is failing** — asserts the **v1 cache survives** and
   that `/safe/` *and* `/safe/?v=…` still open offline.
3. **Network restored** — asserts v2 caches the shell, the stale v1 cache is
   cleaned up, and offline still works.

## Running it

Needs Playwright with the `chrome` channel available.

```
npm i playwright          # in a scratch dir, or reuse test/safe/node_modules
node test/sw/offline_resilience.mjs
```

Exit code 0 means all checks passed.

## Proving the test has teeth

Drop the pre-fix worker at `test/sw/sw_old.js` (e.g.
`git show 71dcd81:public/safe/sw.js > test/sw/sw_old.js`) and run:

```
node test/sw/offline_resilience.mjs --old
```

It **must fail** phase 2 — the v1 cache is deleted and both offline navigations
die with `net::ERR_FAILED`. A test that passes against the broken worker is not
testing anything. `sw_old.js` is gitignored; generate it when you need it.
