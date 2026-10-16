// Art for Level 5: strangers, guards, hotel workers and Uncle; rats; the street, Mom's kitchen,
// the hotel lobby, the corridors and Uncle's room. (A port of StreetArt.swift.)
(function () {
  const D = SN.draw;
  function at(ctx, x, y, w, h, fn) { ctx.save(); ctx.translate(x - w / 2, y - h); fn(w, h); ctx.restore(); }
  function grad(ctx, y0, y1, a, b) { const g = ctx.createLinearGradient(0, y0, 0, y1); g.addColorStop(0, a); g.addColorStop(1, b); return g; }

  /// A grown-up you don't know. outfit: 'stranger' | 'guardian' | 'worker' | 'uncle'. Feet on (x, y).
  function person(ctx, x, y, outfit, style = 0, o = {}) {
    const t = o.t ?? SN.now();
    const swing = o.walking ? Math.sin(t * 8) : 0;
    const skins = SN.look.skins;
    const coat = outfit === 'stranger' ? [SN.white(0.32), SN.rgb(0.22, 0.35, 0.25), SN.rgb(0.45, 0.18, 0.22), SN.rgb(0.18, 0.22, 0.42)][Math.abs(style) % 4]
      : outfit === 'guardian' ? SN.rgb(0.12, 0.16, 0.32)
      : outfit === 'worker' ? (style % 2 === 0 ? SN.rgb(0.62, 0.14, 0.20) : SN.rgb(0.85, 0.85, 0.90))
      : SN.rgb(0.35, 0.28, 0.22);
    const skin = outfit === 'stranger' ? skins[Math.abs(style * 2 + 1) % skins.length] : outfit === 'guardian' ? skins[3]
      : outfit === 'worker' ? skins[Math.abs(style + 1) % skins.length] : skins[1];
    const sleeve = SN.shade(coat, -0.08);
    const arm = (cx, top, deg) => D.rotated(ctx, cx, top, deg, () => { D.capsule(ctx, 0, 31, 20, 62, sleeve); D.circle(ctx, 0, 63, 18, skin); });
    ctx.save(); ctx.translate(x, y);
    if (o.facingRight === false) ctx.scale(-1, 1);
    ctx.translate(-70, -250);
    D.rotated(ctx, 60, 164, swing * 20, () => D.capsule(ctx, 0, 41, 22, 82, SN.white(0.16)));
    D.rotated(ctx, 80, 164, -swing * 20, () => D.capsule(ctx, 0, 41, 22, 82, SN.white(0.20)));
    arm(64, 94, -swing * 22);
    D.rrect(ctx, 70, 128, 74, 104, 22, coat);
    // Extras
    if (outfit === 'guardian') {
      D.rect(ctx, 70, 150, 74, 8, SN.white(0.1));
      D.star(ctx, 86, 104, 8, SN.colors.gold);
      D.rotated(ctx, 128, 155, -78, () => {
        const g = ctx.createLinearGradient(0, 0, 0, 190); g.addColorStop(0, 'rgba(255,204,0,.45)'); g.addColorStop(1, 'rgba(255,204,0,0)');
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(55, 190); ctx.lineTo(-55, 190); ctx.closePath(); ctx.fillStyle = g; ctx.fill();
      });
    } else if (outfit === 'worker') {
      if (style % 2 === 0) for (let n = 0; n < 3; n++) D.circle(ctx, 84, 100 + n * 18, 7, SN.colors.gold);
      else {
        D.rrect(ctx, 74, 142, 50, 70, 8, SN.rgb(0.3, 0.55, 0.75));
        D.rotated(ctx, 118, 170, 14, () => D.capsule(ctx, 0, 0, 6, 150, SN.rgb(0.6, 0.45, 0.3)));
        D.ellipse(ctx, 100, 244, 40, 16, SN.white(0.85));
      }
    } else if (outfit === 'uncle') {
      D.tri(ctx, 78, 94, 30, 34, '#fff', false);
      D.capsule(ctx, 78, 108, 9, 40, '#ff3b30');
    } else {
      D.rrect(ctx, 74, 150, 46, 22, 8, 'rgba(0,0,0,.18)');
    }
    const frontArm = outfit === 'guardian' ? -62 : outfit === 'worker' ? -35 : swing * 22;
    arm(78, 94, frontArm);
    D.circle(ctx, 72, 52, 60, skin);
    // Hats
    if (outfit === 'stranger') {
      ctx.beginPath(); ctx.arc(68, 50, 36, Math.PI * 0.84, Math.PI * 2); ctx.closePath(); ctx.fillStyle = SN.shade(coat, -0.06); ctx.fill();
    } else if (outfit === 'guardian') {
      D.dome(ctx, 72, 46, 64, 60, coat); D.capsule(ctx, 94, 44, 40, 9, SN.white(0.08));
    } else if (outfit === 'worker') {
      if (style % 2 === 0) D.rrect(ctx, 72, 22, 44, 20, 4, coat); else D.dome(ctx, 72, 46, 62, 56, SN.rgb(0.3, 0.55, 0.75));
    } else D.dome(ctx, 72, 48, 62, 58, SN.white(0.55));
    // Face
    const blink = (t + 1.7) % 3.4 < 0.15;
    D.capsule(ctx, 78, 52, 7, blink ? 1.5 : 7, '#111'); D.capsule(ctx, 92, 52, 7, blink ? 1.5 : 7, '#111');
    if (outfit === 'stranger') {
      D.rotated(ctx, 77, 44, 18, () => D.capsule(ctx, 0, 0, 12, 3, 'rgba(0,0,0,.75)'));
      D.rotated(ctx, 93, 44, -18, () => D.capsule(ctx, 0, 0, 12, 3, 'rgba(0,0,0,.75)'));
      D.capsule(ctx, 86, 67, 14, 3, 'rgba(0,0,0,.6)');
    } else if (outfit === 'uncle') {
      D.capsule(ctx, 86, 65, 26, 8, SN.white(0.45));
      D.circle(ctx, 76, 34, 13, null, SN.white(0.2), 2); D.circle(ctx, 92, 34, 13, null, SN.white(0.2), 2);
    } else D.capsule(ctx, 86, 67, 12, 3, 'rgba(0,0,0,.6)');
    ctx.restore();
  }

  function rat(ctx, x, y, facingRight) {
    ctx.save(); ctx.translate(x, y - 20); if (!facingRight) ctx.scale(-1, 1);
    D.capsule(ctx, -34, 6, 40, 4, SN.rgb(0.85, 0.6, 0.65));
    D.ellipse(ctx, 0, 0, 50, 28, SN.white(0.5));
    D.circle(ctx, 24, -4, 24, SN.white(0.55));
    D.circle(ctx, 20, -16, 13, SN.rgb(0.9, 0.65, 0.7));
    D.circle(ctx, 29, -6, 4, '#000'); D.circle(ctx, 36, -1, 5, SN.rgb(0.9, 0.5, 0.6));
    ctx.restore();
  }

  Object.assign(SN.people, { person, rat });

  // The street's houses: the same row every time.
  const houses = (() => {
    const r = SN.seeded(55), list = [];
    for (let x = 330; x < 4850;) { const w = 200 + r() * 160; list.push({ x, w, h: 200 + r() * 170, lit: Math.floor(r() * 4), tone: r() }); x += w + 24; }
    return list;
  })();

  Object.assign(SN.props, {
    streetScene(ctx, width) {
      ctx.fillStyle = grad(ctx, 0, 520, SN.palette.skyTop(), SN.palette.skyBottom()); ctx.fillRect(0, 0, width, 520);
      ctx.save(); ctx.shadowColor = SN.palette.moon(); ctx.shadowBlur = 30; D.circle(ctx, 700, 150, 90, SN.palette.moon()); ctx.restore();
      for (const h of houses) {
        const wall = SN.rgb(0.16 + h.tone * 0.10, 0.14 + h.tone * 0.06, 0.28 + h.tone * 0.08);
        const cx = h.x + h.w / 2;
        D.rect(ctx, cx, 520 - h.h / 2, h.w, h.h, wall);
        D.tri(ctx, cx, 520 - h.h - 35, h.w + 30, 70, SN.shade(wall, -0.05));
        for (let n = 0; n < 3; n++) D.rrect(ctx, cx + (n - 1) * (36 + h.w / 5), 520 - h.h * 0.5 - 22 - 20, 36, 44, 4, n === h.lit ? 'rgba(255,204,0,.8)' : SN.rgb(0.08, 0.07, 0.16));
        D.rrect(ctx, cx, 520 - 39, 44, 78, 4, SN.rgb(0.30, 0.20, 0.16));
      }
      // Your house
      D.rect(ctx, 150, 520 - 165, 300, 330, SN.rgb(0.30, 0.24, 0.42));
      D.tri(ctx, 150, 520 - 330 - 55, 340, 110, SN.rgb(0.40, 0.22, 0.30));
      D.rrect(ctx, 230, 520 - 237, 60, 54, 6, 'rgba(255,204,0,.85)');
      // The hotel
      const hx = width - 330;
      D.rect(ctx, hx, 520 - 235, 640, 470, SN.rgb(0.42, 0.26, 0.30));
      for (let row = 0; row < 3; row++) for (let col = 0; col < 6; col++) {
        D.rrect(ctx, hx - 220 + col * 88, 163 + row * 88, 54, 62, 5, (row + col) % 3 === 0 ? 'rgba(255,204,0,.85)' : SN.rgb(0.14, 0.12, 0.24));
      }
      ctx.save(); ctx.shadowColor = '#ff9500'; ctx.shadowBlur = 12; D.text(ctx, 'HOTEL', hx, 520 - 445, 54, '#ffcc00', 900); ctx.restore();
      D.rrect(ctx, hx + 20, 520 - 315, 220, 30, 8, SN.rgb(0.75, 0.15, 0.2));
      // Pavement and road
      ctx.fillStyle = SN.rgb(0.36, 0.36, 0.42); ctx.fillRect(0, 510, width, 190);
      ctx.fillStyle = SN.rgb(0.50, 0.50, 0.56); ctx.fillRect(0, 510, width, 10);
      ctx.fillStyle = 'rgba(255,255,255,.12)';
      for (let i = 0; i < width / 260; i++) ctx.fillRect(i * 260 + 130, 520, 3, 190);
      // Lamp posts
      for (let i = 0; i < Math.floor(width / 620); i++) {
        const lx = i * 620 + 430, top = 222;
        const g = ctx.createRadialGradient(lx, top - 0, 4, lx, top, 150); g.addColorStop(0, 'rgba(255,204,0,.35)'); g.addColorStop(1, 'rgba(255,204,0,0)');
        ctx.fillStyle = g; ctx.fillRect(lx - 150, top - 150, 300, 300);
        D.rect(ctx, lx, top + 150, 8, 300, SN.white(0.2)); D.capsule(ctx, lx + 20, top + 4, 50, 8, SN.white(0.2)); D.circle(ctx, lx + 40, top + 13, 22, '#ffcc00');
      }
    },
    busStop(ctx, x, y, hiding) {
      at(ctx, x, y, 190, 240, () => {
        D.rrect(ctx, 95, 130, 170, 220, 8, 'rgba(140,204,242,.35)', SN.white(0.25), 6);
        D.rect(ctx, 95, 37, 190, 22, SN.rgb(0.2, 0.4, 0.75)); D.text(ctx, '🚌', 95, 37, 18, '#fff');
        D.rect(ctx, 95, 196, 130, 12, SN.rgb(0.5, 0.35, 0.2));
        if (hiding) [83, 107].forEach(ex => { D.circle(ctx, ex, 130, 12, '#fff'); D.circle(ctx, ex, 130, 6, '#000'); });
      });
    },
    kitchenWall(ctx, width) {
      ctx.fillStyle = SN.rgb(0.36, 0.42, 0.48); ctx.fillRect(0, 0, width, 545);
      ctx.fillStyle = 'rgba(255,255,255,.05)'; for (let i = 0; i < width / 60; i++) ctx.fillRect(i * 60, 0, 2, 545);
      ctx.fillStyle = SN.rgb(0.55, 0.42, 0.30); ctx.fillRect(0, 545, width, 155);
      ctx.fillStyle = grad(ctx, 195, 325, SN.palette.skyTop(), SN.palette.skyBottom());
      ctx.beginPath(); ctx.roundRect(710, 195, 180, 130, 8); ctx.fill(); ctx.strokeStyle = 'rgba(255,255,255,.8)'; ctx.lineWidth = 8; ctx.stroke();
      D.rect(ctx, 800, 438, 560, 16, SN.rgb(0.85, 0.83, 0.78));
      D.rect(ctx, 800, 499, 540, 106, SN.rgb(0.40, 0.28, 0.20));
      D.rrect(ctx, 620, 496, 130, 100, 6, SN.white(0.2));
      D.circle(ctx, 596, 426, 34, null, '#ff9500', 4); D.circle(ctx, 644, 426, 34, null, '#ff9500', 4);
      D.rrect(ctx, 980, 428, 120, 14, 8, SN.white(0.72)); D.capsule(ctx, 980, 404, 8, 44, SN.white(0.6));
      D.text(ctx, "Mom's kitchen", 300, 200, 20, 'rgba(255,255,255,.25)', 900);
    },
    lobbyWall(ctx, width) {
      ctx.fillStyle = grad(ctx, 0, 545, SN.rgb(0.36, 0.16, 0.20), SN.rgb(0.48, 0.24, 0.26)); ctx.fillRect(0, 0, width, 545);
      for (let i = 0; i < width / 120; i++) D.star(ctx, i * 120 + 60, i % 2 === 0 ? 180 : 300, 9, SN.alpha(SN.colors.gold, 0.25));
      ctx.fillStyle = SN.alpha(SN.colors.gold, 0.5); ctx.fillRect(0, 440, width, 6);
      ctx.fillStyle = SN.rgb(0.30, 0.12, 0.16); ctx.fillRect(0, 446, width, 100);
      ctx.fillStyle = SN.rgb(0.22, 0.26, 0.42); ctx.fillRect(0, 545, width, 155);
      ctx.fillStyle = SN.alpha(SN.colors.gold, 0.35); ctx.fillRect(0, 600, width, 5);
      D.rrect(ctx, 1100, 486, 360, 120, 10, SN.rgb(0.42, 0.28, 0.18));
      D.rect(ctx, 1100, 424, 380, 10, SN.colors.gold);
      D.text(ctx, 'RECEPTION', 1100, 480, 22, SN.colors.gold, 900);
      for (let i = 0; i < 3; i++) P.chandelier(ctx, 500 + i * 700, 110, 60);
    },
    chandelier(ctx, x, y, size) {
      const g = ctx.createRadialGradient(x, y + 10, 4, x, y + 10, size * 2); g.addColorStop(0, 'rgba(255,204,0,.5)'); g.addColorStop(1, 'rgba(255,204,0,0)');
      ctx.fillStyle = g; ctx.fillRect(x - size * 2, y + 10 - size * 2, size * 4, size * 4);
      D.rect(ctx, x, y - size * 0.5, 4, size * 0.6, SN.colors.gold);
      D.dome(ctx, x, y + size * 0.2, size * 0.8, size * 0.6, SN.colors.gold);
      D.ellipse(ctx, x, y + size * 0.22, size * 0.5, size * 0.12, '#fff3b0');
    },
    corridorWall(ctx, width, floor) {
      ctx.fillStyle = grad(ctx, 0, 545, SN.rgb(0.20, 0.24, 0.36), SN.rgb(0.30, 0.32, 0.44)); ctx.fillRect(0, 0, width, 545);
      ctx.fillStyle = 'rgba(255,255,255,.05)'; for (let i = 0; i < width / 90; i++) ctx.fillRect(i * 90, 0, 30, 545);
      ctx.fillStyle = SN.alpha(SN.colors.gold, 0.5); ctx.fillRect(0, 440, width, 6);
      ctx.fillStyle = SN.rgb(0.16, 0.18, 0.28); ctx.fillRect(0, 446, width, 100);
      ctx.fillStyle = SN.rgb(0.45, 0.14, 0.18); ctx.fillRect(0, 545, width, 155);
      ctx.fillStyle = SN.alpha(SN.colors.gold, 0.35); ctx.fillRect(0, 600, width, 5);
      for (let i = 0; i <= width / 600; i++) D.text(ctx, 'FLOOR ' + floor, 340 + i * 600, 150, 26, SN.alpha(SN.colors.gold, 0.8), 900);
      for (let i = 0; i < 4; i++) P.chandelier(ctx, 300 + i * 480, 70, 44);
    },
    officeWall(ctx, width) {
      ctx.fillStyle = SN.rgb(0.30, 0.36, 0.34); ctx.fillRect(0, 0, width, 545);
      ctx.fillStyle = SN.rgb(0.45, 0.32, 0.22); ctx.fillRect(0, 545, width, 155);
      ctx.save(); ctx.beginPath(); ctx.roundRect(170, 185, 320, 190, 8); ctx.clip();
      ctx.fillStyle = grad(ctx, 185, 375, SN.palette.skyTop(), SN.palette.skyBottom()); ctx.fillRect(170, 185, 320, 190);
      ctx.translate(330, 362); ctx.scale(0.5, 0.5); P.car(ctx, 0, 0); ctx.restore();
      D.rrect(ctx, 330, 280, 320, 190, 8, null, 'rgba(255,255,255,.8)', 8);
      D.rrect(ctx, 720, 496, 300, 100, 8, SN.rgb(0.36, 0.22, 0.14));
      D.rect(ctx, 720, 442, 320, 12, SN.rgb(0.50, 0.32, 0.20));
      D.text(ctx, 'MANAGER', 720, 500, 16, SN.colors.gold, 900);
    },
    lobbyPlant(ctx, x, y, hiding) {
      at(ctx, x, y, 180, 240, () => {
        for (let i = 0; i < 7; i++) D.rotated(ctx, 90, 156, (i - 3) * 20, () => D.ellipse(ctx, 0, -75, 46, 150, SN.rgb(0.16, 0.50 + (i % 3) * 0.06, 0.26)));
        D.rrect(ctx, 90, 198, 96, 84, 12, SN.rgb(0.70, 0.42, 0.26));
        if (hiding) [79, 101].forEach(ex => { D.circle(ctx, ex, 104, 12, '#fff'); D.circle(ctx, ex, 104, 6, '#000'); });
      });
    },
    elevatorDoor(ctx, x, y, floor) {
      at(ctx, x, y, 150, 330, () => {
        D.rrect(ctx, 75, 17, 54, 34, 6, '#000'); D.text(ctx, floor === 1 ? 'L' : String(floor), 75, 18, 22, '#ff9500', 900);
        D.rrect(ctx, 75, 185, 150, 290, 6, SN.white(0.55));
        const l = ctx.createLinearGradient(8, 0, 75, 0); l.addColorStop(0, SN.white(0.85)); l.addColorStop(1, SN.white(0.65));
        ctx.fillStyle = l; ctx.fillRect(8, 47, 65, 276);
        const r = ctx.createLinearGradient(77, 0, 142, 0); r.addColorStop(0, SN.white(0.65)); r.addColorStop(1, SN.white(0.85));
        ctx.fillStyle = r; ctx.fillRect(77, 47, 65, 276);
        D.capsule(ctx, 162, 185, 24, 48, SN.white(0.4)); D.circle(ctx, 162, 176, 12, '#ff9500'); D.circle(ctx, 162, 194, 12, SN.white(0.3));
      });
    },
  });
  const P = SN.props;
})();
