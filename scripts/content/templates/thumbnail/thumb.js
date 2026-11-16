/*
 * Shared rendering helpers for the three thumbnail frames (2026-11-16).
 *
 * Each frame defines window.SF_LAYOUT(spec) -> html for its middle section and
 * then calls SF_THUMB_RENDER(spec, middleHtml). What lives here is everything
 * all three must do IDENTICALLY:
 *
 *   - the size switch (one template, two formats — the instruction's rule)
 *   - the brand row and the 第NN回 badge
 *   - shrink-to-fit
 *   - 🔴 the safe-area MEASUREMENT
 *
 * ── Why the safe area is measured and not trusted ──────────────────────────
 *
 * tokens.css puts text inside #safe, and that is the intent. The measurement
 * is a different claim: that no text node's painted box actually crosses the
 * line. A headline shrunk by fitToBox, a two-line label that wrapped to three,
 * or an outline-offset on the focus row can all push pixels past a boundary
 * the CSS still "says" it respects — and on a Shorts cover the consequence is
 * invisible until it is public, because the platform draws its UI on top.
 *
 * So SF_THUMB_RENDER returns `outside`: the text nodes whose bottom or right
 * edge leaves the safe box, with their names and how far. make_thumbnail.mjs
 * reports them. Nothing here hides a violation by clipping it.
 */
(function () {
  'use strict';

  var SIZES = { short: { w: 1080, h: 1920, safeH: 1280 }, long: { w: 1280, h: 720, safeH: 720 } };

  window.SF_THUMB_SIZES = SIZES;

  window.SF_ESC = function (s) {
    return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c];
    });
  };

  /* Two lines, each its own <span class="l">.
   *
   * `accent` is what makes variant A and variant B different — which line
   * carries the marker. Two variants that differ only in colour are one
   * variant, so this moves the emphasis rather than recolouring it. */
  window.SF_HEAD = function (lines, accent, redLine) {
    var esc = window.SF_ESC;
    return '<p class="head">' + (lines || []).map(function (t, i) {
      var cls = 'l';
      if (i === redLine) cls += ' red';
      var inner = esc(t);
      if (i === accent) inner = '<span class="hl">' + inner + '</span>';
      return '<span class="' + cls + '">' + inner + '</span>';
    }).join('') + '</p>';
  };

  /* The document close-up. `rows` arrive already resolved: make_thumbnail.mjs
   * has turned field KEYS into the app's own Japanese labels, so an unknown
   * key fails there rather than printing a key name onto a thumbnail. */
  window.SF_DOC = function (doc) {
    if (!doc || !doc.rows || !doc.rows.length) return '';
    var esc = window.SF_ESC;
    return '<div class="doc">'
      + (doc.title ? '<div class="dt">' + esc(doc.title) + '</div>' : '')
      + doc.rows.map(function (r) {
          var cls = 'row' + (r.focus ? ' focus' : '') + (r.masked ? '' : ' keep');
          return '<div class="' + cls + '"><span class="lbl">' + esc(r.label) + '</span>'
            + '<span class="val' + (r.masked ? ' masked' : '') + '">' + esc(r.value) + '</span></div>';
        }).join('')
      + '</div>';
  };

  /* Shrink to fit rather than clip — the carousel's and the Shorts card's rule.
   * A thumbnail that lost the end of its headline still looks finished, and
   * that is the failure that ships. */
  function fitToBox(el, min) {
    var scale = 1;
    var sel = '.head,.doc .row,.doc .lbl,.doc .val,.doc .dt,.note,.steps .n,.vs .col,.warnbar';
    function fits() { return el.scrollHeight <= el.clientHeight + 1; }
    while (!fits() && scale > min) {
      scale = Math.round((scale - 0.02) * 100) / 100;
      Array.prototype.forEach.call(el.querySelectorAll(sel), function (n) {
        if (!n.dataset.basePx) n.dataset.basePx = String(parseFloat(getComputedStyle(n).fontSize));
        n.style.fontSize = (parseFloat(n.dataset.basePx) * scale) + 'px';
      });
    }
    return { scale: scale, overflowed: !fits() };
  }

  /* Every text-bearing node that must stay inside the safe box, measured
   * against the CARD's coordinates (not the safe box's own, which would make
   * the check tautological). */
  function outsideSafeArea(card, size) {
    var safe = document.getElementById('safe');
    var cardBox = card.getBoundingClientRect();
    var limitBottom = cardBox.top + size.safeH;
    // The right 8% of a Shorts frame carries the action buttons.
    var limitRight = cardBox.left + (size === SIZES.short ? size.w * 0.92 : size.w);
    var out = [];
    Array.prototype.forEach.call(
      safe.querySelectorAll('.head,.head .l,.note,.doc .lbl,.doc .val,.doc .dt,.badge,.brand,.steps .n,.steps .t,.vs .col,.warnbar'),
      function (n) {
        if (!n.textContent.trim()) return;
        var b = n.getBoundingClientRect();
        if (b.height === 0 || b.width === 0) return;
        var over = [];
        if (b.bottom > limitBottom + 1) over.push('bottom by ' + Math.round(b.bottom - limitBottom) + 'px');
        if (b.right > limitRight + 1) over.push('right by ' + Math.round(b.right - limitRight) + 'px');
        if (over.length) {
          out.push({
            what: (n.className || n.tagName).toString().split(' ')[0],
            text: n.textContent.trim().slice(0, 24),
            over: over.join(' + ')
          });
        }
      }
    );
    return out;
  }

  window.SF_THUMB_RENDER = function (spec, middleHtml) {
    var size = SIZES[spec.size];
    if (!size) throw new Error('SF_THUMB: unknown size "' + spec.size + '"');

    var esc = window.SF_ESC;
    var card = document.getElementById('card');
    card.className = spec.size;
    card.style.width = size.w + 'px';
    card.style.height = size.h + 'px';

    card.innerHTML =
      '<div id="safe">'
      + '<div class="top">'
      + '<div class="brand"><span class="bar"></span>SafeFile<span class="slim">／SlimFile</span></div>'
      + '<div class="badge">' + esc(spec.badge) + '</div>'
      + '</div>'
      + middleHtml
      + '<div class="note">' + esc(spec.note) + '</div>'
      + '</div>'
      + '<div id="fill"><div class="sheet"></div><div class="veil"></div></div>';

    var fit = fitToBox(document.getElementById('safe'), 0.55);
    var outside = outsideSafeArea(card, size);
    window.SF_THUMB_READY = true;
    return { scale: fit.scale, overflowed: fit.overflowed, outside: outside, size: { w: size.w, h: size.h } };
  };
})();
