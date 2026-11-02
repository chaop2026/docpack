/* SafeFile JP landing pages — measurement + pilot form.
 *
 * Two jobs, both deliberately small:
 *
 *  1. landing_view / cta_click counters, sent to our OWN /api/safe_events with
 *     navigator.sendBeacon. Category values only — the page's `from` slug and
 *     the purpose the CTA carries. No cookie is set, no identifier is
 *     generated, nothing is read back.
 *
 *     ⚠️ S11: the three landing PAGES now also load Google Analytics 4, in
 *     their own <head>, with Signals and ad personalisation turned off and
 *     /privacy/ saying so in Japanese. This file is not where that lives and
 *     must not become it — the GA tag belongs to the marketing pages, and the
 *     counters below belong to the product. /safe/, the screen where a
 *     document is actually opened, still carries NO third-party script at all,
 *     and test/integration/jp_analytics_scope_test.rb pins that boundary in
 *     both directions.
 *
 *  2. The pilot form on /safe/jp/nyusatsu/, posted as JSON so the page can show
 *     a thank-you in place without a navigation.
 *
 * Every failure here is silent by design: a counter that cannot be sent must
 * not change what the visitor sees. The form is the exception — a submit that
 * fails says so, because the visitor is waiting on it.
 */
(function () {
  'use strict';

  var FROM = document.documentElement.getAttribute('data-from') || 'direct';

  /* Which channel sent this visit, and which episode's link it was.
   *
   * Mapped onto the fixed lists the server accepts (SafeEvent::VALUES) rather
   * than passed through: a free-text parameter is a visitor-controlled string,
   * and the whole premise of this endpoint is that only category values are
   * stored. Anything unrecognised becomes 'other', absent becomes 'none' —
   * the two are different facts and are kept apart.
   *
   * ── Why two parameter names (S10) ────────────────────────────────────────
   *
   * `?via=` is what every link published from 2026-11-01 carries. `?utm_source=`
   * is what the ones already out there carry — blog bodies, tweets, the earlier
   * pinned tweet — and those keep being clicked.
   *
   * The switch is not cosmetic: ad/tracker-blocking extensions strip or block
   * `?utm_*` BEFORE the request leaves the browser, so those visits were
   * arriving with no source at all and being counted as 'none'. The server was
   * answering 200 the whole time, which is why it looked like nothing was
   * wrong.
   *
   * `via` wins when both are present. Nothing is written to storage and nothing
   * is read back; both are derived from the current URL on each page load. */
  var PARAMS = (function () {
    try { return new URLSearchParams(window.location.search); }
    catch (e) { return null; }
  })();

  function pick(name, allowed) {
    try {
      if (!PARAMS) return 'none';
      var v = PARAMS.get(name);
      if (!v) return 'none';
      v = v.toLowerCase();
      return allowed.indexOf(v) >= 0 ? v : 'other';
    } catch (e) { return 'none'; }
  }

  /* Two lists, not one shared one (S11).
   *
   * `via` gained `email` — outreach mail is the channel with actual volume
   * right now and those visits were arriving unattributed. `utm_source` did
   * NOT, because it describes links that are already published and that list
   * is frozen.
   *
   * They have to be separate arrays, and this is not tidiness: the server
   * validates each key against its OWN list (SafeEvent::VALUES), and an
   * unknown value makes `sanitize` return nil, which discards the ENTIRE
   * event rather than one field. Sharing one array here would mean that
   * `?utm_source=email` was accepted by this file, sent, and then thrown away
   * whole by the server — and since sendBeacon never reads the response, the
   * loss would be invisible from both ends. */
  var VIA_CHANNELS = ['x', 'linkedin', 'youtube', 'blog', 'email', 'direct'];
  var UTM_CHANNELS = ['x', 'linkedin', 'youtube', 'blog', 'direct'];
  var VIA = pick('via', VIA_CHANNELS);
  var UTM_SOURCE = VIA === 'none' ? pick('utm_source', UTM_CHANNELS) : 'none';

  /* epNN, two digits, ep01-ep33 — the planned run. Built here rather than
   * written out so the list cannot drift from SafeEvent::VALUES["ep"]. */
  var EPISODES = (function () {
    var out = [];
    for (var i = 1; i <= 33; i++) out.push('ep' + (i < 10 ? '0' : '') + i);
    return out;
  })();
  var EP = pick('ep', EPISODES);

  /* Only the dimensions this visit actually has. Sending `via: 'none'` AND
   * `utm_source: 'none'` on every direct visit would double-count the same
   * non-fact in two columns of the weekly table. */
  function attribution() {
    var p = {};
    if (VIA !== 'none') p.via = VIA;
    if (UTM_SOURCE !== 'none') p.utm_source = UTM_SOURCE;
    if (EP !== 'none') p.ep = EP;
    return p;
  }

  function assign(target, extra) {
    for (var k in extra) { if (Object.prototype.hasOwnProperty.call(extra, k)) target[k] = extra[k]; }
    return target;
  }

  function beacon(name, props) {
    try {
      var body = JSON.stringify({ name: name, props: props || {} });
      var blob = new Blob([body], { type: 'application/json' });
      if (navigator.sendBeacon && navigator.sendBeacon('/api/safe_events', blob)) return;
      // sendBeacon returns false when the queue is full; a keepalive fetch is
      // the documented fallback and is still fire-and-forget.
      fetch('/api/safe_events', { method: 'POST', headers: { 'content-type': 'application/json' }, body: body, keepalive: true }).catch(function () {});
    } catch (e) { /* never surfaces */ }
  }

  beacon('landing_view', assign({ from: FROM, locale: 'ja' }, attribution()));

  // CTA clicks. `data-purpose` mirrors the purpose in the link's own query
  // string so the counter and the destination cannot disagree.
  Array.prototype.forEach.call(document.querySelectorAll('[data-cta]'), function (el) {
    el.addEventListener('click', function () {
      var p = assign({ from: FROM, locale: 'ja' }, attribution());
      var purpose = el.getAttribute('data-purpose');
      if (purpose) p.purpose = purpose;
      beacon('cta_click', p);
    });
  });

  /* ── pilot form ── */
  var form = document.getElementById('pilotForm');
  if (!form) return;

  var msg = document.getElementById('pilotMsg');
  var btn = document.getElementById('pilotSubmit');

  function show(kind, text) {
    msg.className = 'pf-msg ' + kind;
    msg.textContent = text;
  }

  form.addEventListener('submit', function (ev) {
    ev.preventDefault();
    var fd = new FormData(form);
    var payload = {};
    fd.forEach(function (v, k) { payload[k] = v; });
    payload.from = FROM;

    btn.disabled = true;
    var prev = btn.textContent;
    btn.textContent = '送信中…';

    fetch('/api/jp_pilot', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload)
    }).then(function (res) {
      if (res.status === 201) {
        form.reset();
        show('ok', 'お申し込みをお受けしました。2営業日以内にご連絡いたします。よく提出される発注者名をお知らせいただいた場合は、その指示に合わせたプリセットを用意してお送りします。');
        form.querySelectorAll('input, select, button').forEach(function (el) { el.disabled = true; });
        return;
      }
      if (res.status === 429) {
        show('err', '送信が集中しています。しばらくしてからもう一度お試しください。');
        return;
      }
      // The server answers with FIELD NAMES, never rendered messages — a
      // Japanese page must not display the server's locale. The wording lives
      // here, next to the labels it refers to.
      var FIELD_JA = {
        company: '会社名',
        industry: '業種',
        monthly_count: '月間提出件数',
        authority: 'よく使う発注者',
        email: '連絡先メール',
        from: '流入元'
      };
      return res.json().then(function (j) {
        var fields = (j && j.errors && j.errors.length)
          ? j.errors.map(function (f) { return FIELD_JA[f] || f; })
          : [];
        show('err', fields.length
          ? 'つぎの項目をご確認ください：' + fields.join('、')
          : '入力内容をご確認ください。');
      }).catch(function () {
        show('err', '入力内容をご確認ください。');
      });
    }).catch(function () {
      show('err', '送信できませんでした。通信環境をご確認のうえ、もう一度お試しください。chaop2@gmail.com へ直接ご連絡いただいても対応いたします。');
    }).finally(function () {
      if (msg.className.indexOf('ok') === -1) { btn.disabled = false; btn.textContent = prev; }
    });
  });
})();
