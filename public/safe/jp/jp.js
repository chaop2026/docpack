/* SafeFile JP landing pages — measurement + pilot form.
 *
 * Two jobs, both deliberately small:
 *
 *  1. landing_view / cta_click counters, sent to our OWN /api/safe_events with
 *     navigator.sendBeacon. Category values only — the page's `from` slug and
 *     the purpose the CTA carries. No cookie is set, no identifier is
 *     generated, nothing is read back. There is no third-party script on these
 *     pages and this file must never become the place one is added.
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

  /* Which channel sent this visit. Mapped onto the fixed list the server
   * accepts (SafeEvent::VALUES["utm_source"]) rather than passed through:
   * a free-text utm_source is a visitor-controlled string, and the whole
   * premise of this endpoint is that only category values are stored. Anything
   * unrecognised becomes 'other', absent becomes 'none' — the two are different
   * facts and are kept apart.
   *
   * Nothing is written to storage and nothing is read back; this is derived
   * from the current URL on each page load. */
  var UTM_SOURCE = (function () {
    try {
      var allowed = ['x', 'linkedin', 'youtube', 'blog', 'direct'];
      var v = new URLSearchParams(window.location.search).get('utm_source');
      if (!v) return 'none';
      return allowed.indexOf(v.toLowerCase()) >= 0 ? v.toLowerCase() : 'other';
    } catch (e) { return 'none'; }
  })();

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

  beacon('landing_view', { from: FROM, locale: 'ja', utm_source: UTM_SOURCE });

  // CTA clicks. `data-purpose` mirrors the purpose in the link's own query
  // string so the counter and the destination cannot disagree.
  Array.prototype.forEach.call(document.querySelectorAll('[data-cta]'), function (el) {
    el.addEventListener('click', function () {
      var p = { from: FROM, locale: 'ja', utm_source: UTM_SOURCE };
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
