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
    const backArm = taunting ? 160 + wiggle * 20 : crouching ? -48 + swing * 16 : scared ? -140 + idle * 6 : -swing * 30 + 4 + idle * 4;
    const frontArm = taunting ? -160 - wiggle * 20 : crouching ? -72 - swing * 16 : scared ? -150 - idle * 6 : swing * 30 - 4 - idle * 4;
    const drop = crouching ? 24 + breath * 1.2 - Math.abs(swing) * 2 : 0;

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s * (opts.facingRight === false ? -1 : 1), s);
    ctx.translate(-50, -160);
    // A taunt wobbles the whole body from the feet.
    if (wiggle) { ctx.translate(50, 160); ctx.rotate(wiggle * 8 * Math.PI / 180); ctx.translate(-50, -160); }

    // Legs
    if (crouching) {
      bentLeg(ctx, 17, 111 - Math.max(0, swing) * 3, -swing * 6, c);
      bentLeg(ctx, 31, 111 - Math.max(0, -swing) * 3, swing * 6, c);
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
  function bentLeg(ctx, ox, oy, shuffle, c) {
    D.capsule(ctx, ox + 20, oy + 9, 34, 17, c.trousers);
    D.capsule(ctx, ox + 30 + shuffle, oy + 22, 16, 24, SN.shade(c.trousers, -0.06));
    D.capsule(ctx, ox + 34 + shuffle, oy + 34, 24, 11, c.shoe);
  }
  function arm(ctx, deg, c) {
    D.rotated(ctx, 50, 59, deg, () => {
      D.capsule(ctx, 0, 18, 14, 36, c.shirt);
      D.circle(ctx, 0, 39.5, 13, c.skin);
    });
  }

  function upperBody(ctx, look, c, backArm, frontArm, swing, glance, t, mood, taunting) {
    const acc = look.accessory ? SN.accessories.find(a => a.id === look.accessory) : null;
    if (acc && acc.family === 'cape') D.rotated(ctx, 34, 63, 8 + swing * 6, () => D.rrect(ctx, 0, 33, 34, 66, 10, acc.color));
    if (look.shirtStyle === 1) D.ellipse(ctx, 34, 62, 50, 30, SN.shade(c.shirt, -0.1));
    hairBehind(ctx, look, c);
    arm(ctx, backArm, c);
    torso(ctx, look, c);
    arm(ctx, frontArm, c);
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
    if (look.shirtStyle === 1) {
      D.rrect(ctx, 54, 102, 30, 12, 6, SN.shade(c.shirt, -0.08));
      D.capsule(ctx, 58, 70, 2.5, 14, 'rgba(255,255,255,.85)'); D.capsule(ctx, 66, 70, 2.5, 12, 'rgba(255,255,255,.85)');
    } else if (look.shirtStyle === 2) {
      for (let i = 0; i < 4; i++) D.rect(ctx, 50, 70 + i * 11, 44, 4, 'rgba(255,255,255,.35)');
    } else if (look.shirtStyle === 3) {
      D.rect(ctx, 60, 86, 12, 50, 'rgba(255,255,255,.92)');
      D.rect(ctx, 54, 86, 3, 50, SN.shade(c.shirt, -0.12)); D.rect(ctx, 67, 86, 3, 50, SN.shade(c.shirt, -0.12));
    }
    const pattern = L.patterns[look.pattern % L.patterns.length];
    if (pattern && look.shirtStyle !== 3) {
      const col = look.shirt === 5 ? '#fff' : SN.colors.gold;
      if (pattern === 'star') D.star(ctx, 63, 75, 8, col);
      if (pattern === 'heart') D.heart(ctx, 63, 76, 16, col);
      if (pattern === 'bolt') D.bolt(ctx, 63, 75, 16, col);
      if (pattern === 'moon') D.moon(ctx, 63, 75, 13, col, c.shirt);
      if (pattern === 'paw') D.paw(ctx, 63, 76, 15, col);
    }
  }

  function face(ctx, look, c, glance, t, mood, taunting) {
    const blink = (t + (look.gender === 'boy' ? 0 : 0.9)) % 3.6 < 0.16;
    if (taunting) {
      D.capsule(ctx, 56, 40, 9, 3, '#000'); D.capsule(ctx, 71, 40, 9, 3, '#000');
      D.capsule(ctx, 66, 54, 9, 12, SN.rgb(1, 0.4, 0.5));
    } else {
      const tall = blink ? 1.6 : (mood === 4 || mood === 3) ? 9.5 : mood === 6 ? 3 : mood === 5 ? 4.5 : 7.5;
      [56, 71].forEach(ex => {
        D.capsule(ctx, ex + glance, 40, 6.5, tall, c.eye);
        if (!blink && tall > 4) D.circle(ctx, ex + glance + 1, 40 - tall / 4, 2.2, '#fff');
      });
      const tilt = mood === 2 || mood === 3 ? -16 : mood === 7 ? 18 : mood === 5 ? 8 : 0;
      const lift = mood === 4 ? -4 : mood === 3 ? -3 : 0;
      const brow = SN.shade(c.hair, -0.1);
      D.rotated(ctx, 56 + glance * 0.5, 32 + lift, tilt, () => D.capsule(ctx, 0, 0, 9, 2.5, brow));
      D.rotated(ctx, 71 + glance * 0.5, 32 + lift, -tilt, () => D.capsule(ctx, 0, 0, 9, 2.5, brow));
      mouth(ctx, mood);
    }
    if (look.blush !== false) D.circle(ctx, 76, 50, 9, mood === 1 ? 'rgba(255,45,85,.5)' : 'rgba(255,45,85,.32)');
    if (look.freckles) [[60, 47], [64, 49], [73, 47], [77, 45]].forEach(([fx, fy]) => D.circle(ctx, fx, fy, 2, 'rgba(140,80,40,.6)'));
  }

  function mouth(ctx, mood) {
    ctx.save();
    ctx.strokeStyle = 'rgba(0,0,0,.7)'; ctx.lineWidth = 2.5; ctx.lineCap = 'round';
    ctx.beginPath();
    if (mood === 1) { ctx.arc(64, 46, 8, 0.1 * Math.PI, 0.9 * Math.PI); ctx.stroke(); }
    else if (mood === 3 || mood === 4) { ctx.restore(); D.ellipse(ctx, 64, 51, 7, mood === 4 ? 9 : 6, 'rgba(60,20,30,.85)'); return; }
    else if (mood === 2 || mood === 7) { ctx.arc(64, 56, 7, 1.15 * Math.PI, 1.85 * Math.PI); ctx.stroke(); }
    else if (mood === 5) { ctx.moveTo(58, 51); ctx.quadraticCurveTo(66, 53, 71, 47); ctx.stroke(); }
    else if (mood === 6) { ctx.moveTo(60, 51); ctx.lineTo(68, 51); ctx.stroke(); }
    else { ctx.arc(64, 47, 7, 0.2 * Math.PI, 0.8 * Math.PI); ctx.stroke(); }
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
      D.rotated(ctx, 58, 60, 15, () => D.capsule(ctx, 0, 0, 14, 3, '#000'));
      D.rotated(ctx, 82, 60, -15, () => D.capsule(ctx, 0, 0, 14, 3, '#000'));
      const blink = (t + 1.3) % 3.6 < 0.16;
      D.capsule(ctx, 59, 68, 7, blink ? 1.5 : 7, '#111'); D.capsule(ctx, 81, 68, 7, blink ? 1.5 : 7, '#111');
      D.capsule(ctx, 70, 84, 18, 4, 'rgba(0,0,0,.7)');
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
      const blink = (t + 2.1) % 3.6 < 0.16;
      D.capsule(ctx, 60, 60, 6, blink ? 1.5 : 6, '#111'); D.capsule(ctx, 82, 60, 6, blink ? 1.5 : 6, '#111');
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

  SN.people = { character, mom, dad, guide, speech, stunStars,
    brotherLook: Object.assign(SN.look.starter('boy'), { skin: 1, shirt: 3, pattern: 4 }) };
})();
