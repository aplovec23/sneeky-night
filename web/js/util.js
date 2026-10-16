// Small helpers shared by everything: maths, colours and the canvas shapes the game is drawn with.
// Everything lives on one global object, SN, so the game runs from plain <script> files.
var SN = window.SN || {};
window.SN = SN;

SN.clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
SN.lerp = (a, b, t) => a + (b - a) * t;
SN.ease = p => { const q = SN.clamp(p, 0, 1); return q * q * (3 - 2 * q); };
SN.rand = (lo, hi) => lo + Math.random() * (hi - lo);
SN.randInt = (lo, hiExclusive) => Math.floor(SN.rand(lo, hiExclusive));
SN.pick = list => list[Math.floor(Math.random() * list.length)];
SN.shuffle = list => { const a = list.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
SN.now = () => performance.now() / 1000;

/// The same random numbers every time for the same seed (stars on the wall, houses on the street...).
SN.seeded = function (seed) {
  let s = (seed * 2654435761) >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
};

/// Colours are written as [r, g, b] from 0 to 1 (like the iPad version) or as CSS strings.
SN.rgb = (r, g, b, a = 1) => `rgba(${Math.round(r * 255)},${Math.round(g * 255)},${Math.round(b * 255)},${a})`;
SN.white = (w, a = 1) => SN.rgb(w, w, w, a);
/// Lighter or darker (like SwiftUI's .brightness): amount from -1 to 1.
SN.shade = function (css, amount) {
  const c = SN.parse(css);
  const f = v => amount >= 0 ? v + (255 - v) * amount : v * (1 + amount);
  return `rgba(${Math.round(f(c[0]))},${Math.round(f(c[1]))},${Math.round(f(c[2]))},${c[3]})`;
};
SN.alpha = function (css, a) { const c = SN.parse(css); return `rgba(${c[0]},${c[1]},${c[2]},${a})`; };
SN._parseCache = {};
SN.parse = function (css) {
  if (SN._parseCache[css]) return SN._parseCache[css];
  const ctx = SN._probe || (SN._probe = document.createElement('canvas').getContext('2d'));
  ctx.fillStyle = '#000'; ctx.fillStyle = css;
  let v = ctx.fillStyle, out;
  if (v[0] === '#') out = [parseInt(v.slice(1, 3), 16), parseInt(v.slice(3, 5), 16), parseInt(v.slice(5, 7), 16), 1];
  else { const m = v.match(/[\d.]+/g).map(Number); out = [m[0], m[1], m[2], m.length > 3 ? m[3] : 1]; }
  SN._parseCache[css] = out;
  return out;
};

SN.colors = {
  gold: SN.rgb(1, 0.8, 0.25),
  silver: SN.rgb(0.8, 0.84, 0.9),
  button: SN.rgb(0.98, 0.62, 0.2),
  red: '#ff3b30', orange: '#ff9500', yellow: '#ffcc00', green: '#34c759', mint: '#00c7be', teal: '#30b0c7',
  cyan: '#32ade6', blue: '#007aff', indigo: '#5856d6', purple: '#af52de', pink: '#ff2d55', brown: '#a2845e', gray: '#8e8e93',
};

// ---------- Canvas shapes (all positions are centres, like the iPad version) ----------
SN.draw = {
  rect(ctx, cx, cy, w, h, fill) { ctx.fillStyle = fill; ctx.fillRect(cx - w / 2, cy - h / 2, w, h); },
  rrect(ctx, cx, cy, w, h, r, fill, stroke, lw) {
    ctx.beginPath(); ctx.roundRect(cx - w / 2, cy - h / 2, w, h, Math.min(r, w / 2, h / 2));
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lw || 2; ctx.stroke(); }
  },
  /// A pill shape (rounded at both ends).
  capsule(ctx, cx, cy, w, h, fill) { SN.draw.rrect(ctx, cx, cy, w, h, Math.min(w, h) / 2, fill); },
  circle(ctx, cx, cy, d, fill, stroke, lw) {
    ctx.beginPath(); ctx.arc(cx, cy, d / 2, 0, Math.PI * 2);
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lw || 2; ctx.stroke(); }
  },
  ellipse(ctx, cx, cy, w, h, fill, stroke, lw) {
    ctx.beginPath(); ctx.ellipse(cx, cy, w / 2, h / 2, 0, 0, Math.PI * 2);
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lw || 2; ctx.stroke(); }
  },
  /// The top half of an ellipse (hair, caps).
  dome(ctx, cx, cy, w, h, fill) {
    ctx.beginPath(); ctx.ellipse(cx, cy, w / 2, h / 2, 0, Math.PI, Math.PI * 2); ctx.closePath();
    ctx.fillStyle = fill; ctx.fill();
  },
  tri(ctx, cx, cy, w, h, fill, up = true) {
    ctx.beginPath();
    if (up) { ctx.moveTo(cx, cy - h / 2); ctx.lineTo(cx + w / 2, cy + h / 2); ctx.lineTo(cx - w / 2, cy + h / 2); }
    else { ctx.moveTo(cx - w / 2, cy - h / 2); ctx.lineTo(cx + w / 2, cy - h / 2); ctx.lineTo(cx, cy + h / 2); }
    ctx.closePath(); ctx.fillStyle = fill; ctx.fill();
  },
  /// A shape drawn rotated by `deg` around (px, py), e.g. an arm swinging from the shoulder.
  rotated(ctx, px, py, deg, fn) {
    ctx.save(); ctx.translate(px, py); ctx.rotate(deg * Math.PI / 180); fn(); ctx.restore();
  },
  text(ctx, s, cx, cy, size, fill, weight = 800, align = 'center') {
    ctx.font = `${weight} ${size}px ui-rounded, "SF Pro Rounded", system-ui, sans-serif`;
    ctx.textAlign = align; ctx.textBaseline = 'middle'; ctx.fillStyle = fill; ctx.fillText(s, cx, cy);
  },
  star(ctx, cx, cy, r, fill) {
    ctx.beginPath();
    for (let i = 0; i < 10; i++) {
      const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 === 0 ? r : r * 0.45;
      ctx.lineTo(cx + Math.cos(a) * rr, cy + Math.sin(a) * rr);
    }
    ctx.closePath(); ctx.fillStyle = fill; ctx.fill();
  },
  heart(ctx, cx, cy, s, fill) {
    ctx.beginPath(); ctx.moveTo(cx, cy + s * 0.35);
    ctx.bezierCurveTo(cx - s * 0.6, cy - s * 0.1, cx - s * 0.3, cy - s * 0.55, cx, cy - s * 0.2);
    ctx.bezierCurveTo(cx + s * 0.3, cy - s * 0.55, cx + s * 0.6, cy - s * 0.1, cx, cy + s * 0.35);
    ctx.fillStyle = fill; ctx.fill();
  },
  bolt(ctx, cx, cy, s, fill) {
    ctx.beginPath();
    const p = [[0.1, -0.5], [-0.25, 0.05], [0, 0.05], [-0.1, 0.5], [0.25, -0.05], [0, -0.05]];
    p.forEach(([x, y], i) => i ? ctx.lineTo(cx + x * s, cy + y * s) : ctx.moveTo(cx + x * s, cy + y * s));
    ctx.closePath(); ctx.fillStyle = fill; ctx.fill();
  },
  moon(ctx, cx, cy, s, fill, back) {
    SN.draw.circle(ctx, cx, cy, s, fill);
    SN.draw.circle(ctx, cx + s * 0.28, cy - s * 0.18, s * 0.8, back);
  },
  paw(ctx, cx, cy, s, fill) {
    SN.draw.ellipse(ctx, cx, cy + s * 0.15, s * 0.5, s * 0.42, fill);
    [[-0.3, -0.12], [-0.1, -0.32], [0.12, -0.32], [0.32, -0.12]].forEach(([x, y]) => SN.draw.circle(ctx, cx + x * s, cy + y * s, s * 0.2, fill));
  },
  key(ctx, cx, cy, s, fill) {
    SN.draw.circle(ctx, cx - s * 0.25, cy, s * 0.45, fill);
    SN.draw.circle(ctx, cx - s * 0.25, cy, s * 0.18, 'rgba(0,0,0,.35)');
    SN.draw.rect(ctx, cx + s * 0.15, cy, s * 0.5, s * 0.12, fill);
    SN.draw.rect(ctx, cx + s * 0.32, cy + s * 0.1, s * 0.08, s * 0.16, fill);
  },
};

/// Small emoji-style pictures for the HTML parts (buttons, backpack, pop-ups).
SN.icon = {
  key: '🔑', star: '⭐', home: '🏠', restart: '↻', pause: '⏸', hint: '💡', hand: '✋', up: '⬆', crouch: '⤓',
  box: '📦', taunt: '😜', run: '🏃', dash: '💨', lock: '🔒', paper: '📄', moon: '🌙', clock: '⏱', warn: '⚠️',
  toy: '🧸', leaf: '🍃', bolt: '⚡', bat: '🏏', cloud: '☁️', hat: '🎩', gift: '🎁', socks: '🧦', slippers: '🥿',
  phone: '📱', back: '‹', sound: '🔊', music: '🎵', gear: '⚙️', map: '🗺', badge: '🏅', shirt: '👕', folder: '📁',
  people: '👥', hammer: '🔨', book: '📖', signpost: '🪧', news: '📰', check: '✓', play: '▶',
};

/// Calls fn after `seconds`, unless the level was restarted meanwhile (`run` changed).
SN.later = function (owner, seconds, fn) {
  const run = owner.run;
  setTimeout(() => { if (owner.run === run) fn(); }, seconds * 1000);
};

SN.el = function (html) {
  const t = document.createElement('template');
  t.innerHTML = html.trim();
  return t.content.firstElementChild;
};
SN.esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
