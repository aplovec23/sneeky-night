// Drawing people on the canvas: you (any look), your brother, Mom, Dad and the Guide,
// plus speech bubbles. Shapes and sizes follow the iPad version's CharacterView, MomView and DadView.
(function () {
  const D = SN.draw;
  const L = SN.look;

  // ---------- Speech bubbles ----------
  function wrap(ctx, text, maxW) {
    const words = String(text).split(' ');
    const lines = []; let line = '';
    for (const w of words) {
      const test = line ? line + ' ' + w : w;
      if (ctx.measureText(test).width > maxW && line) { lines.push(line); line = w; } else line = test;
    }
    if (line) lines.push(line);
    return lines;
  }

  /// A cream speech bubble with a coloured rim and a tail; (x, y) is the tip of the tail.
  function speech(ctx, x, y, text, tint = SN.colors.gold, small = true) {
    const size = small ? 17 : 21;
    ctx.save();
    ctx.font = `700 ${size}px ui-rounded, "SF Pro Rounded", system-ui, sans-serif`;
    const lines = wrap(ctx, text, small ? 240 : 290);
    const w = Math.max(...lines.map(l => ctx.measureText(l).width)) + 36;
    const h = lines.length * (size + 5) + 22;
    const bx = x - w / 2, by = y - h - 12;
    ctx.shadowColor = 'rgba(0,0,0,.3)'; ctx.shadowBlur = 8; ctx.shadowOffsetY = 3;
    const g = ctx.createLinearGradient(0, by, 0, by + h);
    g.addColorStop(0, '#ffffff'); g.addColorStop(1, '#fff2d6');
    ctx.beginPath(); ctx.roundRect(bx, by, w, h, 20); ctx.fillStyle = g; ctx.fill();
    ctx.shadowColor = 'transparent';
    ctx.lineWidth = 3.5; ctx.strokeStyle = tint; ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x - 11, by + h - 1); ctx.lineTo(x, y); ctx.lineTo(x + 11, by + h - 1); ctx.closePath();
    ctx.fillStyle = '#fff2d6'; ctx.fill();
    ctx.beginPath(); ctx.moveTo(x - 11, by + h); ctx.lineTo(x, y); ctx.lineTo(x + 11, by + h); ctx.strokeStyle = tint; ctx.stroke();
    D.star(ctx, bx + 4, by + 4, 7, tint);
    ctx.fillStyle = '#2e1f4d'; ctx.textAlign = 'center'; ctx.textBaseline = 'top';
    lines.forEach((l, i) => ctx.fillText(l, x, by + 12 + i * (size + 5)));
    ctx.restore();
  }

  function stunStars(ctx, x, y, t) {
    for (let i = 0; i < 3; i++) {
      const a = t * 4 + i * 2.1;
      D.star(ctx, x + Math.cos(a) * 26, y + Math.sin(a) * 8, 7, '#ffcc00');
    }
  }

  // ---------- You (and your brother) ----------
  function colorsOf(look) {
    const shirt = L.shirts[look.shirt % L.shirts.length];
    const hairPicked = look.hairColor > 0 ? L.hairColors[look.hairColor % L.hairColors.length] : null;
    return {
      skin: L.skins[look.skin % L.skins.length],
      shirt,
      hair: hairPicked || (look.gender === 'boy' ? SN.rgb(0.33, 0.21, 0.12) : SN.rgb(0.55, 0.30, 0.14)),
      trousers: look.pants >= 0 ? L.pants[look.pants % L.pants.length] : SN.shade(shirt, -0.22),
      shoe: L.shoes[Math.abs(look.shoes || 0) % L.shoes.length],
      eye: L.eyes[Math.abs(look.eyes || 0) % L.eyes.length],
      cap: L.caps[look.cap % L.caps.length],
    };
  }

  /// Draws a character so their feet stand on (x, y). opts: facingRight, walking, crouching, taunting, scale, t, mood.
  function character(ctx, x, y, look, opts = {}) {
    const t = opts.t ?? SN.now();
    const s = opts.scale ?? 1;
    const c = colorsOf(look);
    const crouching = !!opts.crouching, taunting = !!opts.taunting, walking = !!opts.walking;
    const swing = walking ? Math.sin(t * (crouching ? 8 : 13)) : 0;
    const wiggle = taunting ? Math.sin(t * 22) : 0;
    const breath = Math.sin(t * (crouching ? 2.4 : 1.8) + look.skin);
    const mood = taunting ? 1 : (opts.mood ?? look.face ?? 0);
    const idle = walking || taunting || crouching ? 0 : breath;
    const scared = mood === 3 && !taunting && !crouching;
    // Taunting: both hands up beside the head, waving. Crouching: hands out in front, creeping
    // forward one after the other. Scared: arms stiff and a little forward, trembling.
    const tremble = scared ? Math.sin(t * 38) * 3 : 0;
    const backArm = taunting ? 140 + wiggle * 18 : crouching ? -24 + swing * 12 : scared ? -14 + tremble : -swing * 30 + 5 + idle * 4;
    const frontArm = taunting ? -140 - wiggle * 18 : crouching ? -42 - swing * 12 : scared ? -26 - tremble : swing * 30 - 6 - idle * 4;
    // Crouching is a squat: knees out in front, the upper body lowered and leaning over them.
    // The shoes stay on the floor line, the same as standing, so the feet never sink.
    const drop = crouching ? 22 + breath * 1.2 - Math.abs(swing) * 2 : 0;
    // Creeping: one knee and then the other moves forward, its foot lifting a little.
    const step = swing * 6;

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s * (opts.facingRight === false ? -1 : 1), s);
    ctx.translate(-50, -160);
    // A taunt wobbles the whole body from the feet.
    if (wiggle) { ctx.translate(50, 160); ctx.rotate(wiggle * 8 * Math.PI / 180); ctx.translate(-50, -160); }

    // Legs
    if (crouching) {
      crouchLeg(ctx, 44, 126, 70 - step, 122, 62 - step, 142 - Math.max(0, -step) * 0.6, true, c);
      crouchLeg(ctx, 52, 126, 80 + step, 121, 72 + step, 142 - Math.max(0, step) * 0.6, false, c);
    } else {
      leg(ctx, 42, 102.5, swing * 28, c);
      leg(ctx, 58, 102.5, -swing * 28, c);
    }

    // Upper body: leans forward when crouching, bobs while walking.
    ctx.save();
    const tilt = crouching ? 9 + swing * 2 : idle * 1.2;
    ctx.translate(50, 160); ctx.rotate(tilt * Math.PI / 180); ctx.translate(-50, -160);
    ctx.translate(0, drop + idle * 1.2 + (walking && !crouching ? -Math.abs(swing) * 2.5 : 0));
    const glance = crouching ? breath * 2.2 : walking ? 0 : glanceAt(t, look.skin);
    upperBody(ctx, look, c, backArm, frontArm, swing, glance, t, mood, taunting);
    ctx.restore();
    ctx.restore();
  }

  function glanceAt(t, seed) {
    const cycle = (t + seed * 1.7) % 7;
    if (cycle < 1.2) return Math.sin(cycle / 1.2 * Math.PI) * 3;
    if (cycle > 3.6 && cycle < 4.6) return -Math.sin((cycle - 3.6) * Math.PI) * 2.5;
    return 0;
  }

  function leg(ctx, px, py, deg, c) {
    D.rotated(ctx, px, py, deg, () => {
      D.capsule(ctx, 0, 20, 17, 40, c.trousers);
      D.capsule(ctx, 4, 41.5, 24, 11, c.shoe);
    });
  }
  /// A bent leg for crouching: the hip under the body, the knee out in front, the shin going down
  /// to the shoe, which stands on the floor line.
  function crouchLeg(ctx, hx, hy, kx, ky, fx, fy, far, c) {
    ctx.save();
    ctx.lineCap = 'round';
    ctx.strokeStyle = far ? SN.shade(c.trousers, -0.08) : c.trousers; ctx.lineWidth = 16;
    ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(kx, ky); ctx.stroke();
    ctx.strokeStyle = SN.shade(c.trousers, far ? -0.1 : -0.03); ctx.lineWidth = 14;
    ctx.beginPath(); ctx.moveTo(kx, ky); ctx.lineTo(fx, fy); ctx.stroke();
    ctx.restore();
    D.capsule(ctx, fx + 5, fy + 2.5, 24, 11, far ? SN.shade(c.shoe, -0.06) : c.shoe);
  }

  // The character is drawn turned a little toward the way they face (facing right; the whole figure
  // is mirrored to face left). So the near arm hangs on the facing side of the body, in front of it,
  // and the far arm on the other side, behind it.
  const NEAR_SHOULDER = 64, FAR_SHOULDER = 36;
  /// An arm hanging from the shoulder, turned `deg` degrees. The sleeve is a shade darker than the
  /// shirt so the arm shows against it; the far arm is darker still.
  function arm(ctx, x, deg, far, c) {
    D.rotated(ctx, x, 59, deg, () => {
      D.capsule(ctx, 0, 18, 14, 36, SN.shade(c.shirt, far ? -0.16 : -0.07));
      D.circle(ctx, 0, 39.5, 13, far ? SN.shade(c.skin, -0.05) : c.skin);
    });
  }

  function upperBody(ctx, look, c, backArm, frontArm, swing, glance, t, mood, taunting) {
    const acc = look.accessory ? SN.accessories.find(a => a.id === look.accessory) : null;
    if (acc && acc.family === 'cape') D.rotated(ctx, 34, 63, 8 + swing * 6, () => D.rrect(ctx, 0, 33, 34, 66, 10, acc.color));
    if (look.shirtStyle === 1) D.ellipse(ctx, 34, 62, 50, 30, SN.shade(c.shirt, -0.1));
    hairBehind(ctx, look, c);
    arm(ctx, FAR_SHOULDER, backArm, true, c);
    torso(ctx, look, c);
    arm(ctx, NEAR_SHOULDER, frontArm, false, c);
    // Head and ear
    D.circle(ctx, 50, 38, 54, c.skin);
    D.ellipse(ctx, 40, 42, 9, 13, SN.shade(c.skin, -0.05));
    if (c.cap) {
      D.dome(ctx, 50, 34, 60, 60, c.cap);
      D.capsule(ctx, 76, 31, 30, 9, SN.shade(c.cap, -0.12));
      D.circle(ctx, 50, 5, 7, 'rgba(255,255,255,.85)');
    } else hairOnTop(ctx, look, c);
    face(ctx, look, c, glance, t, mood, taunting);
    if (acc) wear(ctx, acc.family, acc.color);
    boostGear(ctx, look);
  }

  function torso(ctx, look, c) {
    D.rrect(ctx, 50, 86, 46, 52, 14, c.shirt);
    // The pocket, strings, jacket and picture sit in the middle of the chest, where the near arm
    // doesn't cover them.
    if (look.shirtStyle === 1) {
      D.rrect(ctx, 46, 102, 28, 12, 6, SN.shade(c.shirt, -0.08));
      D.capsule(ctx, 44, 70, 2.5, 14, 'rgba(255,255,255,.85)'); D.capsule(ctx, 52, 70, 2.5, 12, 'rgba(255,255,255,.85)');
    } else if (look.shirtStyle === 2) {
      for (let i = 0; i < 4; i++) D.rect(ctx, 50, 70 + i * 11, 44, 4, 'rgba(255,255,255,.35)');
    } else if (look.shirtStyle === 3) {
      D.rect(ctx, 47, 86, 12, 50, 'rgba(255,255,255,.92)');
      D.rect(ctx, 41, 86, 3, 50, SN.shade(c.shirt, -0.12)); D.rect(ctx, 54, 86, 3, 50, SN.shade(c.shirt, -0.12));
    }
    const pattern = L.patterns[look.pattern % L.patterns.length];
    if (pattern && look.shirtStyle !== 3) {
      const col = look.shirt === 5 ? '#fff' : SN.colors.gold;
      if (pattern === 'star') D.star(ctx, 46, 77, 8, col);
      if (pattern === 'heart') D.heart(ctx, 46, 78, 16, col);
      if (pattern === 'bolt') D.bolt(ctx, 46, 77, 16, col);
      if (pattern === 'moon') D.moon(ctx, 46, 77, 13, col, c.shirt);
      if (pattern === 'paw') D.paw(ctx, 46, 78, 15, col);
    }
  }

  function face(ctx, look, c, glance, t, mood, taunting) {
    const blink = (t + (look.gender === 'boy' ? 0 : 0.9)) % 3.6 < 0.16;
    if (taunting) {
      D.capsule(ctx, 56, 40, 9, 3, '#000'); D.capsule(ctx, 71, 40, 9, 3, '#000');
      D.capsule(ctx, 66, 54, 9, 12, SN.rgb(1, 0.4, 0.5));
    } else {
      // Soft, round eyes with a shine. A mood changes their shape a little, never into a stare.
      eye(ctx, 56 + glance, 40, mood, blink, c.eye);
      eye(ctx, 71 + glance, 40, mood, blink, c.eye);
      // Eyebrows: thin, and only gently tilted.
      const tilt = mood === 2 ? -10 : mood === 3 ? -12 : mood === 7 ? 12 : mood === 5 ? 6 : 0;
      const lift = mood === 4 ? -2.5 : mood === 3 ? -2 : 0;
      const brow = SN.shade(c.hair, -0.12);
      D.rotated(ctx, 56 + glance * 0.5, 33 + lift, tilt, () => D.capsule(ctx, 0, 0, 8, 2, brow));
      D.rotated(ctx, 71 + glance * 0.5, 33 + lift, -tilt, () => D.capsule(ctx, 0, 0, 8, 2, brow));
      mouth(ctx, mood);
      // Scared: a little drop of sweat, not a scream.
      if (mood === 3) sweatDrop(ctx, 80, 30);
    }
    if (look.blush !== false) D.circle(ctx, 76, 50, 9, mood === 1 ? 'rgba(255,45,85,.5)' : 'rgba(255,45,85,.32)');
    if (look.freckles) [[60, 47], [64, 49], [73, 47], [77, 45]].forEach(([fx, fy]) => D.circle(ctx, fx, fy, 2, 'rgba(140,80,40,.6)'));
  }

  /// One eye. Happy eyes are little arcs (^ ^), sleepy ones are shut; the others are round with a shine.
  function eye(ctx, x, y, mood, blink, col) {
    if (blink) { D.capsule(ctx, x, y, 7, 1.8, col); return; }
    if (mood === 1 || mood === 6) {
      ctx.save(); ctx.strokeStyle = col; ctx.lineCap = 'round'; ctx.beginPath();
      if (mood === 1) { ctx.lineWidth = 2.2; ctx.arc(x, y + 2, 4, 1.16 * Math.PI, 1.84 * Math.PI); }
      else { ctx.lineWidth = 2; ctx.arc(x, y - 1, 3.5, 0.16 * Math.PI, 0.84 * Math.PI); }
      ctx.stroke(); ctx.restore();
      return;
    }
    const wide = mood === 3 || mood === 4;
    const tall = wide ? 8 : mood === 5 ? 4.2 : 7.2;
    D.capsule(ctx, x, y, wide ? 7.2 : 6.4, tall, col);
    D.circle(ctx, x + 1.1, y - tall / 4, wide ? 2.8 : 2.3, '#fff');
    if (wide) D.circle(ctx, x - 1.4, y + tall / 5, 1.3, 'rgba(255,255,255,.85)');
  }

  function sweatDrop(ctx, x, y) {
    ctx.beginPath();
    ctx.moveTo(x, y - 4.5);
    ctx.bezierCurveTo(x + 1.2, y - 2.4, x + 3, y - 0.6, x + 3, y + 1.4);
    ctx.arc(x, y + 1.4, 3, 0, Math.PI);
    ctx.bezierCurveTo(x - 3, y - 0.6, x - 1.2, y - 2.4, x, y - 4.5);
    ctx.fillStyle = SN.rgb(0.55, 0.8, 1); ctx.fill();
  }

  const MOUTH_LINE = SN.rgb(0.30, 0.16, 0.14, 0.85), MOUTH_SOFT = SN.rgb(0.75, 0.35, 0.38);
  function mouth(ctx, mood) {
    ctx.save();
    ctx.strokeStyle = MOUTH_LINE; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    // A piece of a circle's outline, from `a` to `b` turns clockwise from the right (like SwiftUI's trim).
    const arc = (cx, cy, d, a, b, lw) => { ctx.lineWidth = lw; ctx.beginPath(); ctx.arc(cx, cy, d / 2, a * 2 * Math.PI, b * 2 * Math.PI); ctx.stroke(); };
    switch (mood) {
      case 1: arc(64, 46, 15, 0.05, 0.45, 2.5); break;
      case 2: arc(64, 55, 13, 0.64, 0.86, 2.3); break;
      case 3: // a small wobbly mouth
        ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(58, 52); ctx.lineTo(61, 50); ctx.lineTo(64, 52); ctx.lineTo(67, 50); ctx.lineTo(70, 52); ctx.stroke(); break;
      case 4: D.ellipse(ctx, 64, 51, 5, 6, MOUTH_SOFT); break;
      case 5: D.rotated(ctx, 66, 50, -10, () => D.capsule(ctx, 0, 0, 9, 2.2, MOUTH_LINE)); break;
      case 6: ctx.globalAlpha = 0.8; D.ellipse(ctx, 64, 51, 4, 4, MOUTH_SOFT); break;
      case 7: arc(64, 55, 12, 0.66, 0.84, 2.3); break;
      default: arc(64, 46.5, 13, 0.1, 0.4, 2.3);
    }
    ctx.restore();
  }

  function topHair(ctx, c) {
    D.dome(ctx, 50, 35, 58, 58, c.hair);
    D.rotated(ctx, 60, 18, -12, () => D.capsule(ctx, 0, 0, 30, 12, c.hair));
  }

  function hairBehind(ctx, look, c) {
    const h = c.hair;
    switch (look.hair) {
      case 0: if (look.gender === 'girl') D.rrect(ctx, 50, 50, 62, 66, 22, h); break;
      case 3: D.rrect(ctx, 48, 62, 64, 92, 24, h); break;
      case 4: D.rotated(ctx, 16, 50, 28, () => D.capsule(ctx, 0, 0, 18, 50, h)); D.circle(ctx, 24, 30, 10, '#ff2d55'); break;
      case 6: D.rrect(ctx, 50, 44, 66, 54, 16, h); break;
      case 8:
        D.rotated(ctx, 14, 54, 24, () => D.capsule(ctx, 0, 0, 16, 46, h));
        D.rotated(ctx, 30, 62, 10, () => D.capsule(ctx, 0, 0, 16, 46, h));
        D.circle(ctx, 21, 36, 9, '#ff2d55'); break;
      case 9: D.circle(ctx, 48, 28, 88, h); break;
      case 12: for (let i = 0; i < 6; i++) D.circle(ctx, 22 - i * 1.5, 44 + i * 12, 16 - i, SN.shade(h, i % 2 ? -0.06 : 0)); break;
      case 18: D.rrect(ctx, 47, 64, 68, 96, 26, h); for (let i = 0; i < 4; i++) D.circle(ctx, 20 + i * 18, 110, 22, h); break;
    }
  }

  function hairOnTop(ctx, look, c) {
    const h = c.hair;
    switch (look.hair) {
      case 1:
        D.dome(ctx, 50, 36, 58, 58, h);
        for (let i = 0; i < 5; i++) D.rotated(ctx, 26 + i * 12, 6 + Math.abs(i - 2) * 4, (i - 2) * 22, () => D.tri(ctx, 0, 0, 16, 22, h));
        break;
      case 2:
        for (let i = 0; i < 7; i++) D.circle(ctx, 24 + i * 9, 20 - Math.sin(i / 6 * Math.PI) * 14, 22, h);
        D.circle(ctx, 24, 30, 20, h); break;
      case 3: D.dome(ctx, 50, 35, 60, 60, h); D.rotated(ctx, 62, 18, -16, () => D.capsule(ctx, 0, 0, 34, 13, h)); break;
      case 4: D.dome(ctx, 50, 35, 58, 58, h); D.rotated(ctx, 62, 17, -10, () => D.capsule(ctx, 0, 0, 26, 11, h)); break;
      case 5: case 7: {
        ctx.beginPath(); ctx.arc(50, 38, 27.5, Math.PI * 1.12, Math.PI * 1.94); ctx.closePath(); ctx.fillStyle = SN.shade(h, look.hair === 7 ? -0.08 : -0.05); ctx.fill();
        if (look.hair === 7) { D.capsule(ctx, 50, 7, 44, 18, h); D.capsule(ctx, 54, 2, 30, 12, SN.shade(h, 0.08)); }
        break;
      }
      case 6: D.dome(ctx, 50, 35, 60, 60, h); D.rrect(ctx, 60, 22, 34, 12, 5, h); break;
      case 9: D.dome(ctx, 50, 34, 66, 70, h); break;
      case 10: topHair(ctx, c); D.circle(ctx, 46, 0, 26, h); break;
      case 11: topHair(ctx, c); D.circle(ctx, 30, 6, 22, h); D.circle(ctx, 66, 4, 22, h); break;
      case 13: D.dome(ctx, 50, 37, 62, 66, h); D.rrect(ctx, 51, 32, 58, 11, 4, h); break;
      case 14: D.dome(ctx, 50, 35, 58, 58, h); D.rotated(ctx, 62, 20, -24, () => D.capsule(ctx, 0, 0, 44, 15, h)); break;
      case 15: D.dome(ctx, 50, 35, 58, 58, h); D.rotated(ctx, 64, 9, -18, () => D.ellipse(ctx, 0, 0, 36, 26, h)); break;
      case 16: D.dome(ctx, 50, 35, 58, 58, h); D.rrect(ctx, 50, 6, 52, 18, 3, h); break;
      case 17: break;
      case 19: D.dome(ctx, 50, 35, 58, 58, h); for (let i = 0; i < 4; i++) D.rrect(ctx, 50 + i * 8, 30, 8, 10 + (i % 2) * 4, 2, h); break;
      default:
        topHair(ctx, c);
        if (look.gender === 'girl' && look.hair === 0) { D.circle(ctx, 27.5, 14, 13, '#ff2d55'); D.circle(ctx, 40.5, 14, 13, '#ff2d55'); }
    }
  }

  function crown(ctx, cx, cy, w, color) {
    ctx.beginPath();
    ctx.moveTo(cx - w / 2, cy + w * 0.3); ctx.lineTo(cx - w / 2, cy - w * 0.15); ctx.lineTo(cx - w / 4, cy + w * 0.05);
    ctx.lineTo(cx, cy - w * 0.3); ctx.lineTo(cx + w / 4, cy + w * 0.05); ctx.lineTo(cx + w / 2, cy - w * 0.15); ctx.lineTo(cx + w / 2, cy + w * 0.3);
    ctx.closePath(); ctx.fillStyle = color; ctx.fill();
  }

  function wear(ctx, family, color) {
    switch (family) {
      case 'glasses':
        D.rrect(ctx, 56, 40, 13, 10, 3, color); D.rrect(ctx, 71, 40, 13, 10, 3, color); D.rect(ctx, 58, 37, 30, 3, color); break;
      case 'crown': crown(ctx, 50, 4, 30, color); break;
      case 'bowTie': D.rotated(ctx, 55, 66, 90, () => D.tri(ctx, 0, 0, 12, 10, color)); D.rotated(ctx, 65, 66, -90, () => D.tri(ctx, 0, 0, 12, 10, color)); break;
      case 'scarf': D.capsule(ctx, 50, 64, 46, 11, color); D.rrect(ctx, 38, 76, 10, 24, 3, color); break;
      case 'headband': D.capsule(ctx, 50, 27, 56, 8, color); D.rotated(ctx, 16, 32, 25, () => D.capsule(ctx, 0, 0, 20, 6, color)); break;
      case 'catEars':
        D.tri(ctx, 34, 8, 18, 18, color); D.tri(ctx, 64, 6, 18, 18, color);
        D.tri(ctx, 34, 11, 8, 9, '#ff2d55'); D.tri(ctx, 64, 9, 8, 9, '#ff2d55'); break;
      case 'headphones':
        ctx.save(); ctx.strokeStyle = SN.white(0.2); ctx.lineWidth = 6; ctx.beginPath(); ctx.arc(50, 36, 31, Math.PI * 1.1, Math.PI * 1.9); ctx.stroke(); ctx.restore();
        D.rrect(ctx, 44, 40, 16, 22, 6, color); break;
      case 'halo':
        ctx.save(); ctx.shadowColor = color; ctx.shadowBlur = 8; D.ellipse(ctx, 50, -4, 44, 11, null, color, 4); ctx.restore(); break;
      case 'partyHat': D.tri(ctx, 50, -4, 30, 36, color); D.circle(ctx, 50, -22, 9, '#ffcc00'); break;
      case 'beanie': D.dome(ctx, 50, 32, 60, 62, color); D.capsule(ctx, 50, 30, 62, 10, SN.shade(color, -0.15)); D.circle(ctx, 50, 0, 12, '#fff'); break;
      case 'topHat': D.rect(ctx, 50, -2, 40, 30, color); D.capsule(ctx, 50, 14, 66, 8, color); D.rect(ctx, 50, 8, 40, 5, 'rgba(255,255,255,.7)'); break;
      case 'hairBow': D.rotated(ctx, 33, 10, 90, () => D.tri(ctx, 0, 0, 16, 14, color)); D.rotated(ctx, 47, 10, -90, () => D.tri(ctx, 0, 0, 16, 14, color)); D.circle(ctx, 40, 10, 8, SN.shade(color, -0.15)); break;
      case 'flower':
        for (let i = 0; i < 5; i++) { const a = i * 72 * Math.PI / 180; D.circle(ctx, 36 + Math.sin(a) * 6, 14 - Math.cos(a) * 6, 9, color); }
        D.circle(ctx, 36, 14, 6, '#ffcc00'); break;
    }
  }

  function boostGear(ctx, look) {
    const shown = (look.boosts || []).filter(b => !(look.hiddenBoosts || []).includes(b));
    const capOn = shown.includes('coolCap');
    if (capOn) {
      D.dome(ctx, 50, 34, 60, 60, '#ff3b30'); D.capsule(ctx, 76, 31, 30, 9, SN.rgb(0.7, 0, 0));
      D.rrect(ctx, 50, -4, 14, 20, 3, SN.white(0.8)); D.rect(ctx, 50, -4, 14, 8, '#34c759');
    }
    if (shown.includes('windCrown')) crown(ctx, 50, capOn ? -24 : 4, 24, '#32ade6');
    if (shown.includes('goldenCrown')) {
      ctx.save(); ctx.shadowColor = '#ffcc00'; ctx.shadowBlur = 6;
      crown(ctx, 50, (capOn ? -24 : 4) - (shown.includes('windCrown') ? 18 : 0), 28, SN.colors.gold); ctx.restore();
    }
    if (shown.includes('arrow')) {
      D.rotated(ctx, 30, 82, 35, () => D.capsule(ctx, 0, 0, 5, 70, SN.rgb(0.6, 0.4, 0.2)));
      D.rotated(ctx, 50, 52, 35, () => D.tri(ctx, 0, 0, 14, 14, '#ff9500'));
    }
    if (shown.includes('leaf')) D.rotated(ctx, 26, 70, -30, () => D.ellipse(ctx, 0, 0, 12, 22, '#34c759'));
    if (shown.includes('cloud')) { D.ellipse(ctx, 92, 14, 30, 11, '#fff'); D.circle(ctx, 86, 9, 14, '#fff'); D.circle(ctx, 96, 7, 17, '#fff'); }
    if (shown.includes('waterHose')) {
      // Auntie's green hose, coiled over one shoulder, with its brass nozzle
      D.circle(ctx, 38, 78, 26, null, SN.rgb(0.20, 0.62, 0.30), 4); D.circle(ctx, 38, 78, 18, null, SN.rgb(0.20, 0.62, 0.30), 4);
      D.rotated(ctx, 48, 92, 30, () => D.capsule(ctx, 0, 0, 6, 12, SN.colors.gold));
    }
    if (shown.includes('lightningBall')) {
      ctx.save(); ctx.shadowColor = '#ffcc00'; ctx.shadowBlur = 8; D.circle(ctx, 14, 40, 22, '#ffcc00'); ctx.restore();
      D.bolt(ctx, 14, 40, 16, '#fff');
    }
  }

  // ---------- Grown-ups (140 × 260 frames, feet on the floor) ----------
  function grownUpFrame(ctx, x, y, right, stunned, fn) {
    ctx.save();
    ctx.translate(x, y);
    if (stunned) ctx.rotate(6 * Math.PI / 180);
    ctx.scale(right === false ? -1 : 1, 1);
    ctx.translate(-70, -260);
    fn();
    ctx.restore();
  }

  /// A grown-up's face, with the same moods as yours (0 calm, 1 happy, 2 worried, 3 scared, 4 surprised,
  /// 5 sneaky, 6 sleepy, 7 cross): soft eyes with a shine and gentle eyebrows, never a stare.
  /// (cx, cy) is between the eyes. Like GrownUpFace on the iPad.
  function grownUpFace(ctx, cx, cy, o) {
    const mood = o.mood ?? 0, gap = o.gap ?? 22, size = o.size ?? 7, t = o.t ?? SN.now();
    const blink = (t + (o.phase ?? 0)) % 3.6 < 0.16;
    const wide = mood === 3 || mood === 4;
    const tall = blink ? Math.max(1.5, size * 0.22) : wide ? size * 1.12 : mood === 6 ? size * 0.35 : mood === 5 ? size * 0.55 : size;
    const tilt = mood === 2 ? -10 : mood === 3 ? -12 : mood === 7 ? 13 : mood === 5 ? 6 : 0;
    const lift = mood === 4 ? -3 : mood === 3 ? -2 : 0;
    for (const side of [-1, 1]) {
      const ex = cx + side * gap / 2;
      D.capsule(ctx, ex, cy, size, tall, SN.white(0.08));
      if (!blink && tall > size * 0.5) D.circle(ctx, ex + size * 0.15, cy - tall / 4, Math.max(2, size * 0.32), '#fff');
      D.rotated(ctx, ex, cy - size - 4 + lift - (o.browRise ?? 0), -side * tilt, () => D.capsule(ctx, 0, 0, size * 1.8, 2.5, o.brows || '#000'));
    }
    if (o.mouth === false) return;
    const my = cy + size + 9 + (o.mouthDrop ?? 0), w = gap * 0.8;
    const arc = (y, d, a, b, alpha) => {
      ctx.save(); ctx.strokeStyle = `rgba(0,0,0,${alpha})`; ctx.lineWidth = 3; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.arc(cx, y, d / 2, a * 2 * Math.PI, b * 2 * Math.PI); ctx.stroke(); ctx.restore();
    };
    switch (mood) {
      case 1: arc(my - w / 2 + 2, w, 0.05, 0.45, 0.75); break;
      case 2: arc(my + w / 2 + 2, w, 0.6, 0.9, 0.7); break;
      case 3: case 4: D.ellipse(ctx, cx, my, w * 0.32, w * 0.36, SN.rgb(0.62, 0.28, 0.30)); break; // a small round "oh"
      case 5: D.rotated(ctx, cx + 3, my, -10, () => D.capsule(ctx, 0, 0, w * 0.65, 3, 'rgba(0,0,0,.7)')); break;
      case 6: D.ellipse(ctx, cx, my, 6, 6, SN.rgb(0.35, 0.10, 0.12, 0.8)); break;
      case 7: arc(my + w / 2 + 2, w, 0.62, 0.88, 0.75); break;
      default: arc(my - w * 0.42 + 2, w * 0.85, 0.1, 0.4, 0.7);
    }
  }

  function grownUpArm(ctx, px, py, deg, sleeve, skin) {
    D.rotated(ctx, px, py, deg, () => { D.capsule(ctx, 0, 31, 18, 62, sleeve); D.circle(ctx, 0, 67, 18, skin); });
  }

  function mom(ctx, x, y, o = {}) {
    const t = o.t ?? SN.now();
    const robe = o.robe || SN.rgb(0.85, 0.45, 0.6), skin = SN.rgb(0.96, 0.8, 0.66);
    const swing = o.walking ? Math.sin(t * 9) : Math.sin(t * 1.7) * 0.12;
    const bob = o.walking ? 0 : Math.sin(t * 1.7 + 0.8) * 1.2;
    grownUpFrame(ctx, x, y + bob, o.facingRight, o.stunned, () => {
      grownUpArm(ctx, 24, 114, 18 + swing * 22, SN.shade(robe, -0.06), skin);
      grownUpArm(ctx, 116, 114, -18 - swing * 22, SN.shade(robe, -0.06), skin);
      D.rrect(ctx, 70, 170, 84, 150, 24, robe);
      D.rect(ctx, 70, 170, 84, 10, SN.rgb(0.7, 0.3, 0.45));
      D.capsule(ctx, 48, 248 + swing * 4, 30, 14, '#fff'); D.capsule(ctx, 92, 248 - swing * 4, 30, 14, '#fff');
      D.circle(ctx, 70, 68, 62, skin);
      // Auntie: a grey bun on top
      if (o.bun) D.circle(ctx, 62, 30, 36, SN.white(0.78));
      D.dome(ctx, 70, 64, 68, 68, o.hair || SN.rgb(0.45, 0.28, 0.15));
      if (!o.noCurlers) [46, 62, 78, 94].forEach(cx => D.capsule(ctx, cx, 30, 12, 18, '#32ade6'));
      // Her face: cross when she's after you, surprised when stunned.
      grownUpFace(ctx, 70, 68, { mood: o.stunned ? 4 : o.mood ?? (o.calm ? 0 : 7), gap: 22, size: 7, phase: 1.3, t });
      if (o.stunned) stunStars(ctx, 70, 18, t);
      else if (!o.calm) label(ctx, '?!', 120, 22, 30, '#ffcc00');
    });
  }

  /// Text inside a grown-up's flipped frame: drawn the right way round even when they face left.
  function label(ctx, s, cx, cy, size, fill) {
    if (ctx.getTransform().a >= 0) { D.text(ctx, s, cx, cy, size, fill, 900); return; }
    ctx.save(); ctx.translate(cx, cy); ctx.scale(-1, 1); D.text(ctx, s, 0, 0, size, fill, 900); ctx.restore();
  }

  function dad(ctx, x, y, o = {}) {
    const t = o.t ?? SN.now();
    const pj = SN.rgb(0.35, 0.45, 0.7), skin = SN.rgb(0.94, 0.76, 0.62);
    const swing = o.walking ? Math.sin(t * 9) : Math.sin(t * 1.6) * 0.12;
    grownUpFrame(ctx, x, y, o.facingRight, o.stunned, () => {
      // Legs
      D.rotated(ctx, 58, 180, swing * 18, () => { D.capsule(ctx, 0, 30, 24, 70, pj); D.capsule(ctx, 4, 66, 30, 13, SN.rgb(0.45, 0.3, 0.2)); });
      D.rotated(ctx, 82, 180, -swing * 18, () => { D.capsule(ctx, 0, 30, 24, 70, pj); D.capsule(ctx, 4, 66, 30, 13, SN.rgb(0.45, 0.3, 0.2)); });
      grownUpArm(ctx, 26, 104, 16 + swing * 20, SN.shade(pj, -0.08), skin);
      D.rrect(ctx, 70, 140, 82, 100, 22, pj);
      for (let i = 0; i < 5; i++) D.rect(ctx, 70, 104 + i * 18, 80, 4, 'rgba(255,255,255,.35)');
      // The other arm holds his mug of cocoa.
      D.rotated(ctx, 114, 104, -40 + (o.walking ? -swing * 10 : 0), () => {
        D.capsule(ctx, 0, 28, 18, 58, SN.shade(pj, -0.08)); D.circle(ctx, 0, 60, 18, skin);
        D.rrect(ctx, 6, 70, 22, 24, 4, '#fff'); D.rect(ctx, 6, 60, 20, 4, SN.rgb(0.45, 0.28, 0.15));
      });
      D.circle(ctx, 70, 58, 62, skin);
      D.dome(ctx, 70, 52, 64, 50, SN.rgb(0.3, 0.2, 0.12));
      D.circle(ctx, 60, 60, 16, null, '#222', 2.5); D.circle(ctx, 82, 60, 16, null, '#222', 2.5); D.rect(ctx, 71, 58, 6, 2, '#222');
      grownUpFace(ctx, 71, 60, { mood: o.laughing ? 1 : o.stunned ? 4 : o.mood ?? 0, gap: 22, size: 6, phase: 2.4, t,
        brows: SN.rgb(0.25, 0.18, 0.12), mouthDrop: 11, browRise: 4 });
      // His moustache sits over the top of his mouth.
      D.capsule(ctx, 71, 76, 28, 8, SN.rgb(0.3, 0.2, 0.12));
      if (o.laughing) label(ctx, 'Ha ha!', 120, 18, 22, '#ffcc00');
      else if (o.stunned) stunStars(ctx, 70, 12, t);
      else if (!o.calm) label(ctx, 'Hmm?', 120, 18, 22, '#ffcc00');
    });
  }

  /// The Guide: a kid in a purple top hat with a lantern.
  function guide(ctx, x, y, o = {}) {
    const look = Object.assign(SN.look.starter('boy'), { skin: 2, shirt: 7, pattern: 3, accessory: 'topHat-purple' });
    character(ctx, x, y, look, Object.assign({}, o));
    const dir = o.facingRight === false ? -1 : 1;
    ctx.save(); ctx.shadowColor = '#ffcc00'; ctx.shadowBlur = 14;
    D.rrect(ctx, x + dir * 30, y - 60, 16, 22, 5, '#ffcc00', SN.white(0.25), 3);
    ctx.restore();
  }

  SN.people = { character, mom, dad, guide, speech, stunStars, grownUpFace,
    brotherLook: Object.assign(SN.look.starter('boy'), { skin: 1, shirt: 3, pattern: 4 }) };
})();
