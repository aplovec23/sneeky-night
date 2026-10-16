// Drawings for Level 3: the stairs, downstairs, garage, basement, back yard and the roof, and the
// furniture in them. Each prop draws with its bottom centre on (x, y). (A port of DownstairsArt.swift.)
(function () {
  const D = SN.draw;
  const wood = SN.rgb(0.50, 0.32, 0.20), darkWood = SN.rgb(0.36, 0.22, 0.14);

  function at(ctx, x, y, w, h, fn) { ctx.save(); ctx.translate(x - w / 2, y - h); fn(w, h); ctx.restore(); }
  function grad(ctx, y0, y1, a, b) { const g = ctx.createLinearGradient(0, y0, 0, y1); g.addColorStop(0, a); g.addColorStop(1, b); return g; }

  /// Wall down to 450, a skirting board, then the floor.
  function shell(ctx, width, wallTop, wallBottom, floorTop, floorBottom) {
    ctx.fillStyle = grad(ctx, 0, 450, wallTop, wallBottom); ctx.fillRect(0, 0, width, 450);
    ctx.fillStyle = darkWood; ctx.fillRect(0, 442, width, 16);
    ctx.fillStyle = grad(ctx, 458, 700, floorTop, floorBottom); ctx.fillRect(0, 458, width, 242);
  }

  function flower(ctx, x, y, s = 1, color = '#ff2d55') {
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    D.rect(ctx, 0, 12, 3, 14, SN.rgb(0.2, 0.6, 0.3));
    for (let i = 0; i < 5; i++) { const a = i * 72 * Math.PI / 180; D.circle(ctx, Math.sin(a) * 7, -Math.cos(a) * 7, 10, color); }
    D.circle(ctx, 0, 0, 8, '#ffcc00');
    ctx.restore();
  }

  function nightSky(ctx, width, height, count, seed, moonX, moonY, moonD) {
    ctx.fillStyle = grad(ctx, 0, height, SN.palette.skyTop(), SN.rgb(0.20, 0.17, 0.45)); ctx.fillRect(0, 0, width, height);
    const light = Math.max(SN.palette.starlight(), 0.15);
    for (let i = 0; i < count; i++) D.circle(ctx, (i * seed) % width, (i * 67) % (height - 20), 2 + i % 3, `rgba(255,255,255,${0.85 * light})`);
    ctx.save(); ctx.shadowColor = SN.palette.moon(); ctx.shadowBlur = 30; D.circle(ctx, moonX, moonY, moonD, SN.palette.moon()); ctx.restore();
  }

  function frame(ctx, x, y, seed) { SN.props.picture(ctx, x + 55, y + 43, seed); }

  Object.assign(SN.props, {
    // ---------- Rooms ----------
    stairsWall(ctx, width) {
      shell(ctx, width, SN.rgb(0.22, 0.18, 0.32), SN.rgb(0.32, 0.25, 0.40), SN.rgb(0.42, 0.28, 0.19), SN.rgb(0.52, 0.35, 0.23));
      for (let i = 0; i < width / 90; i++) {
        ctx.fillStyle = `rgba(0,0,0,${0.04 + i * 0.012})`; ctx.fillRect(i * 90, 458, 90, 242);
        ctx.fillStyle = 'rgba(0,0,0,.35)'; ctx.fillRect(i * 90, 458, 4, 242);
      }
      ctx.strokeStyle = darkWood; ctx.lineWidth = 14; ctx.beginPath(); ctx.moveTo(0, 250); ctx.lineTo(width, 400); ctx.stroke();
      for (let i = 0; i < width / 120; i++) { const x = i * 120 + 60, top = 250 + x / width * 150; ctx.fillStyle = darkWood; ctx.fillRect(x, top, 8, 450 - top); }
      [300, 900, 1500].forEach((x, i) => frame(ctx, x, 150 + x / 20, i + 2));
      D.text(ctx, '↓  DOWN  ↓', width / 2, 480, 22, 'rgba(255,255,255,.25)', 900);
    },
    downstairsWall(ctx, width) {
      shell(ctx, width, SN.rgb(0.20, 0.28, 0.30), SN.rgb(0.28, 0.38, 0.38), SN.rgb(0.40, 0.27, 0.18), SN.rgb(0.52, 0.35, 0.23));
      // The kitchen: a tiled wall and a checkered floor
      ctx.fillStyle = SN.rgb(0.75, 0.80, 0.78); ctx.fillRect(1650, 0, 620, 442);
      ctx.fillStyle = 'rgba(0,0,0,.08)';
      for (let i = 0; i < 8; i++) ctx.fillRect(1650, i * 56, 620, 2);
      for (let i = 0; i < 11; i++) ctx.fillRect(1650 + i * 56, 0, 2, 442);
      for (let i = 0; i < 44; i++) {
        const col = i % 11, row = Math.floor(i / 11);
        ctx.fillStyle = (col + row) % 2 === 0 ? SN.white(0.85) : SN.white(0.30);
        ctx.fillRect(1650 + col * 56.4, 458 + row * 60.5, 56.4, 60.5);
      }
      [240, 1000, 2440].forEach((x, i) => frame(ctx, x, 215, i + 4));
      // A rug
      D.rrect(ctx, 740, 625, 520, 120, 20, SN.rgb(0.55, 0.30, 0.25));
      D.rrect(ctx, 740, 625, 500, 100, 14, null, SN.alpha(SN.colors.gold, 0.5), 4);
    },
    garageWall(ctx, width) {
      shell(ctx, width, SN.white(0.30), SN.white(0.40), SN.white(0.34), SN.white(0.46));
      ctx.fillStyle = SN.white(0.55); ctx.fillRect(500, 142, 520, 300);
      ctx.fillStyle = 'rgba(0,0,0,.2)'; for (let i = 0; i < 7; i++) ctx.fillRect(500, 160 + i * 38, 520, 4);
      D.rrect(ctx, 1210, 195, 300, 150, 6, SN.rgb(0.62, 0.50, 0.36));
      ctx.font = '34px system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ['🔨', '🔧', '🪛', '✂️'].forEach((s, i) => ctx.fillText(s, 1105 + i * 68, 195));
      D.ellipse(ctx, 760, 625, 240, 50, 'rgba(0,0,0,.25)');
    },
    basementWall(ctx, width) {
      shell(ctx, width, SN.rgb(0.24, 0.16, 0.14), SN.rgb(0.34, 0.22, 0.18), SN.white(0.26), SN.white(0.36));
      ctx.fillStyle = 'rgba(0,0,0,.18)';
      for (let i = 0; i < 9; i++) ctx.fillRect(0, i * 50, width, 3);
      for (let i = 0; i < width / 110; i++) for (let row = 0; row < 9; row++) ctx.fillRect(i * 110 + (row % 2 ? 55 : 0), row * 50, 3, 50);
      ctx.fillStyle = SN.white(0.5); ctx.fillRect(0, 60, width, 16);
      ctx.fillStyle = SN.rgb(0.6, 0.35, 0.2); ctx.fillRect(0, 86, width, 10);
    },
    yardScene(ctx, width) {
      nightSky(ctx, width, 460, 40, 137, 900, 110, 90);
      ctx.fillStyle = SN.rgb(0.20, 0.16, 0.30); ctx.fillRect(0, 0, 330, 460);
      for (let x = 340; x + 34 < width; x += 46) D.rrect(ctx, x + 17, 385, 34, 150, 4, SN.rgb(0.70, 0.64, 0.56));
      ctx.fillStyle = grad(ctx, 458, 700, SN.rgb(0.10, 0.28, 0.18), SN.rgb(0.14, 0.38, 0.22)); ctx.fillRect(0, 458, width, 242);
      for (let i = 0; i < 9; i++) D.ellipse(ctx, 345 + i * 130, 615 + (i % 2) * 24, 90, 30, SN.white(0.55));
      for (let i = 0; i < 8; i++) flower(ctx, 1193 + i * 46, 515 + (i % 3) * 14, 1.6);
    },
    roofScene(ctx, width, edge) {
      nightSky(ctx, width, 700, 120, 151, 1750, 150, 130);
      // Looking down past each end: the street on one side, the garden on the other.
      P.streetBelow(ctx, 14, 164, edge - 28, 302);
      P.gardenBelow(ctx, width - edge + 14, 164, edge - 28, 302);
      const chimney = (x, s) => { ctx.save(); ctx.translate(x + 55, 500); ctx.scale(s, s); D.rect(ctx, 0, -85, 90, 170, SN.rgb(0.45, 0.22, 0.18)); D.rect(ctx, 0, -173, 110, 22, SN.rgb(0.30, 0.15, 0.12)); ctx.restore(); };
      chimney(1450, 1); chimney(2380, 0.8);
      D.rrect(ctx, 2000, 440, 150, 70, 8, 'rgba(255,204,0,.35)', SN.white(0.25), 6);
      D.rect(ctx, 2700, 405, 6, 150, SN.white(0.2));
      for (let i = 0; i < 3; i++) D.rect(ctx, 2700, 340 + i * 22, 70 - i * 16, 5, SN.white(0.2));
      ctx.fillStyle = SN.rgb(0.34, 0.20, 0.24); ctx.fillRect(0, 480, width, 220);
      for (let row = 0; row < 5; row++) for (let x = row % 2 ? -32 : 0; x < width; x += 64) D.rrect(ctx, x + 30, 504 + row * 44, 60, 40, 10, SN.rgb(0.42, 0.25, 0.28));
      ctx.fillStyle = SN.white(0.55); ctx.fillRect(0, 480, 14, 220); ctx.fillRect(width - 14, 480, 14, 220);
    },
    streetBelow(ctx, x, y, w, h) {
      ctx.save(); ctx.beginPath(); ctx.roundRect(x, y, w, h, 18); ctx.clip();
      ctx.fillStyle = SN.rgb(0.16, 0.17, 0.24); ctx.fillRect(x, y, w, h);
      const cy = y + h / 2;
      ctx.fillStyle = SN.rgb(0.26, 0.26, 0.32); ctx.fillRect(x, cy + 30 - 45, w, 90);
      for (let i = 0; i < 7; i++) D.rect(ctx, x + 40 + i * 72, cy + 30, 34, 5, 'rgba(255,255,255,.5)');
      [SN.rgb(0.45, 0.25, 0.28), SN.rgb(0.28, 0.32, 0.45), SN.rgb(0.40, 0.33, 0.22), SN.rgb(0.25, 0.38, 0.34)].forEach((c, i) => {
        D.rrect(ctx, x + 66 + i * 135, y + 48, 110, 70, 4, c); D.rect(ctx, x + 66 + i * 135, y + 48, 110, 3, 'rgba(0,0,0,.25)');
      });
      for (let i = 0; i < 3; i++) {
        const lx = x + 96 + i * 180, ly = y + 236;
        const g = ctx.createRadialGradient(lx, ly, 2, lx, ly, 46); g.addColorStop(0, 'rgba(255,204,0,.6)'); g.addColorStop(1, 'rgba(255,204,0,0)');
        ctx.fillStyle = g; ctx.fillRect(lx - 46, ly - 46, 92, 92); D.circle(ctx, lx, ly, 9, '#ffcc00');
      }
      D.rrect(ctx, x + 386, y + 198, 64, 30, 8, SN.rgb(0.75, 0.2, 0.22)); D.rrect(ctx, x + 384, y + 198, 30, 20, 5, 'rgba(50,173,230,.5)');
      D.text(ctx, 'THE STREET', x + 66, y + h - 18, 15, 'rgba(255,255,255,.4)', 900);
      ctx.restore();
      D.rrect(ctx, x + w / 2, y + h / 2, w, h, 18, null, 'rgba(255,255,255,.18)', 3);
    },
    gardenBelow(ctx, x, y, w, h) {
      ctx.save(); ctx.beginPath(); ctx.roundRect(x, y, w, h, 18); ctx.clip();
      ctx.fillStyle = SN.rgb(0.16, 0.36, 0.22); ctx.fillRect(x, y, w, h);
      for (let row = 0; row < 7; row++) for (let col = 0; col < 10; col++) {
        if ((row * 3 + col * 5) % 4 === 0) continue;
        const flat = (row + col) % 2 === 0;
        D.rrect(ctx, x + 38 + col * 46, y + 26 + row * 36, flat ? 40 : 9, flat ? 9 : 34, 3, SN.rgb(0.08, 0.24, 0.14));
      }
      for (let i = 0; i < 14; i++) D.circle(ctx, x + (i * 97) % 470 + 26, y + (i * 53) % 230 + 16, 6, ['#ff2d55', '#ffcc00', '#fff', '#ff9500'][i % 4]);
      D.rrect(ctx, x + 491, y + 136, 12, 50, 3, SN.rgb(0.55, 0.40, 0.25));
      D.ellipse(ctx, x + 471, y + 118, 18, 11, SN.rgb(0.78, 0.58, 0.36)); D.ellipse(ctx, x + 471, y + 156, 18, 11, SN.rgb(0.78, 0.58, 0.36));
      D.text(ctx, 'THE GARDEN', x + w - 90, y + h - 18, 15, 'rgba(255,255,255,.4)', 900);
      ctx.restore();
      D.rrect(ctx, x + w / 2, y + h / 2, w, h, 18, null, 'rgba(255,255,255,.18)', 3);
    },

    // ---------- Against the wall ----------
    stairsDoor(ctx, x, y, up) {
      at(ctx, x, y, 110, 300, () => {
        D.rrect(ctx, 55, 150, 110, 300, 6, 'rgba(0,0,0,.75)');
        for (let i = 0; i < 6; i++) { const k = up ? 5 - i : i; D.rect(ctx, 55, 120 + i * 24 + 50, 40 + k * 10, 14, SN.alpha(wood, 0.5 + k * 0.08)); }
        D.text(ctx, up ? '⬆' : '⬇', 55, 60, 40, 'rgba(255,255,255,.8)', 900);
        ctx.strokeStyle = darkWood; ctx.lineWidth = 10; ctx.strokeRect(0, 0, 110, 300);
      });
    },
    couch(ctx, x, y) {
      at(ctx, x, y, 270, 130, () => {
        D.rrect(ctx, 135, 70, 240, 120, 20, SN.rgb(0.30, 0.45, 0.60));
        D.rrect(ctx, 84, 86, 96, 44, 12, SN.rgb(0.38, 0.55, 0.70)); D.rrect(ctx, 186, 86, 96, 44, 12, SN.rgb(0.38, 0.55, 0.70));
        D.rrect(ctx, 17, 87, 34, 86, 14, SN.rgb(0.25, 0.38, 0.52)); D.rrect(ctx, 253, 87, 34, 86, 14, SN.rgb(0.25, 0.38, 0.52));
      });
    },
    bookshelf(ctx, x, y) {
      at(ctx, x, y, 130, 250, () => {
        D.rrect(ctx, 65, 125, 130, 250, 4, darkWood);
        const colors = ['#ff3b30', '#30b0c7', '#ff9500', '#34c759', '#af52de', '#ffcc00', '#007aff'];
        for (let row = 0; row < 4; row++) {
          const top = 10 + row * 60;
          D.rect(ctx, 65, top + 25, 114, 50, wood);
          for (let i = 0; i < 7; i++) { const h = 34 + (i * 7 + row * 5) % 14; D.rect(ctx, 14 + i * 15 + 6, top + 50 - h / 2, 12, h, SN.alpha(colors[(i + row * 3) % 7], 0.85)); }
        }
      });
    },
    fridge(ctx, x, y) {
      at(ctx, x, y, 120, 260, () => {
        D.rrect(ctx, 60, 130, 120, 260, 10, SN.white(0.88));
        D.rect(ctx, 60, 90, 120, 4, 'rgba(0,0,0,.2)');
        D.capsule(ctx, 102, 45, 8, 50, SN.white(0.55)); D.capsule(ctx, 102, 160, 8, 80, SN.white(0.55));
        D.heart(ctx, 40, 42, 22, '#ff3b30'); D.rrect(ctx, 36, 140, 26, 22, 2, '#ffcc00');
      });
    },
    kitchenCounter(ctx, x, y, open) {
      at(ctx, x, y, 190, 166, () => {
        D.capsule(ctx, 78, 17, 18, 34, 'rgba(255,59,48,.8)'); D.rrect(ctx, 112, 21, 50, 26, 6, SN.white(0.3));
        D.rect(ctx, 95, 40, 190, 12, SN.white(0.25));
        D.rect(ctx, 95, 106, 180, 120, SN.rgb(0.90, 0.86, 0.78));
        [[52, open], [138, false]].forEach(([cx, pulled]) => {
          const cy = 75 + (pulled ? 10 : 0);
          if (pulled) { ctx.save(); ctx.shadowColor = 'rgba(0,0,0,.5)'; ctx.shadowBlur = 6; }
          D.rrect(ctx, cx, cy, 76, 34, 3, SN.rgb(0.80, 0.74, 0.64)); D.capsule(ctx, cx, cy, 24, 6, SN.white(0.4));
          if (pulled) ctx.restore();
        });
      });
    },
    frontDoor(ctx, x, y, dogWaiting, gaveKey, t) {
      P.door(ctx, x, y, SN.rgb(0.25, 0.40, 0.30), false, 'FRONT DOOR', '#fff');
      D.rrect(ctx, x, y - 31, 60, 46, 6, SN.white(0.15));
      if (dogWaiting) {
        ctx.save(); ctx.beginPath(); ctx.rect(x - 28, y - 52, 56, 42); ctx.clip();
        P.dog(ctx, x, y + 2, gaveKey, t, 0.45); ctx.restore();
        if (!gaveKey) D.key(ctx, x + 16, y - 20, 16, '#32ade6');
      }
    },
    /// The dog with a key on his collar. Wags his tail.
    dog(ctx, x, y, happy, t, s = 1) {
      ctx.save(); ctx.translate(x, y - 65 * s); ctx.scale(s, s);
      const wag = 35 + 15 * Math.sin((t || SN.now()) * 12);
      const fur = SN.rgb(0.78, 0.58, 0.36), dark = SN.rgb(0.72, 0.52, 0.32);
      D.rotated(ctx, -44, 26, -wag, () => D.capsule(ctx, 0, -18, 14, 36, dark));
      D.capsule(ctx, -17, 52, 14, 22, dark); D.capsule(ctx, 17, 52, 14, 22, dark);
      D.rrect(ctx, 0, 22, 80, 50, 22, fur);
      D.circle(ctx, 26, -10, 58, fur);
      D.ellipse(ctx, 4, -12, 18, 34, SN.rgb(0.50, 0.34, 0.20));
      D.ellipse(ctx, 40, 2, 30, 22, SN.rgb(0.92, 0.82, 0.68));
      D.circle(ctx, 50, -2, 10, '#000'); D.circle(ctx, 30, -18, 7, '#000');
      if (happy) D.capsule(ctx, 42, 14, 9, 14, SN.rgb(1, 0.45, 0.5));
      ctx.restore();
    },
    lockbox(ctx, x, y, open) {
      at(ctx, x, y, 84, 60, () => {
        D.rrect(ctx, 42, 38, 76, 44, 5, SN.rgb(0.55, 0.55, 0.62));
        D.text(ctx, open ? '🔓' : '🔒', 42, 40, 16, '#fff');
        D.rotated(ctx, 1, 7, open ? -70 : 0, () => D.rrect(ctx, 41, 0, 82, 14, 4, SN.rgb(0.42, 0.42, 0.50)));
      });
    },
    lightSwitch(ctx, x, y, on) {
      at(ctx, x, y, 50, 220, () => {
        D.rrect(ctx, 25, 30, 40, 60, 6, SN.white(0.9));
        D.rrect(ctx, 25, on ? 22 : 38, 14, 26, 3, on ? '#ffcc00' : SN.white(0.5));
      });
    },
    bin(ctx, x, y) {
      at(ctx, x, y, 80, 100, () => {
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(80, 0); ctx.lineTo(68, 100); ctx.lineTo(12, 100); ctx.closePath();
        ctx.fillStyle = SN.rgb(0.20, 0.50, 0.75); ctx.fill();
        D.text(ctx, '♻', 40, 52, 34, '#fff', 900);
      });
    },
    car(ctx, x, y) {
      at(ctx, x, y, 400, 190, () => {
        D.rrect(ctx, 190, 74, 240, 80, 40, SN.rgb(0.75, 0.20, 0.22));
        D.rrect(ctx, 190, 75, 190, 50, 20, 'rgba(50,173,230,.5)');
        D.rrect(ctx, 200, 121, 380, 90, 30, SN.rgb(0.80, 0.22, 0.24));
        [78, 322].forEach(cx => { D.circle(ctx, cx, 153, 74, SN.white(0.1)); D.circle(ctx, cx, 153, 30, SN.white(0.6)); });
        D.circle(ctx, 376, 123, 22, 'rgba(255,204,0,.8)');
      });
    },
    workbench(ctx, x, y) {
      at(ctx, x, y, 170, 150, () => {
        D.rect(ctx, 25, 100, 12, 100, darkWood); D.rect(ctx, 145, 100, 12, 100, darkWood);
        D.rrect(ctx, 85, 41, 160, 18, 4, wood);
        D.rrect(ctx, 45, 19, 40, 26, 3, SN.white(0.35));
        ctx.font = '30px system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText('🔨', 119, 16);
      });
    },
    toolbox(ctx, x, y, open) {
      at(ctx, x, y, 100, 70, () => {
        D.rrect(ctx, 50, 45, 90, 50, 5, '#ff3b30');
        D.rotated(ctx, 2, 14, open ? -60 : 0, () => D.rrect(ctx, 48, -6, 96, 16, 5, SN.rgb(0.7, 0.1, 0.1)));
        if (!open) D.capsule(ctx, 50, 0, 36, 8, SN.white(0.2));
      });
    },
    ladder(ctx, x, y) {
      ctx.save(); ctx.translate(x, y); ctx.rotate(6 * Math.PI / 180);
      D.rect(ctx, -27, -145, 10, 290, SN.rgb(0.75, 0.60, 0.35)); D.rect(ctx, 27, -145, 10, 290, SN.rgb(0.75, 0.60, 0.35));
      for (let i = 0; i < 7; i++) D.rect(ctx, 0, -258 + i * 38, 54, 8, SN.rgb(0.68, 0.54, 0.30));
      ctx.restore();
    },
    trunk(ctx, x, y, open) {
      at(ctx, x, y, 140, 96, () => {
        D.rrect(ctx, 70, 59, 130, 70, 6, darkWood);
        D.rect(ctx, 70, 59, 12, 70, SN.alpha(SN.colors.gold, 0.7));
        D.rotated(ctx, 2, 15, open ? -55 : 0, () => D.rrect(ctx, 68, 0, 136, 30, 14, wood));
      });
    },
    washer(ctx, x, y) {
      at(ctx, x, y, 120, 150, () => {
        D.rrect(ctx, 60, 75, 120, 150, 8, SN.white(0.85));
        D.circle(ctx, 60, 91, 76, SN.white(0.3)); D.circle(ctx, 60, 91, 58, 'rgba(50,173,230,.35)');
        D.circle(ctx, 21, 19, 10, '#ff3b30'); D.circle(ctx, 39, 19, 10, '#34c759');
      });
    },
    gardenGate(ctx, x, y) {
      at(ctx, x, y, 220, 300, () => {
        const green = SN.rgb(0.25, 0.55, 0.30);
        ctx.strokeStyle = green; ctx.lineWidth = 26; ctx.beginPath(); ctx.arc(110, 115, 95, Math.PI, 0); ctx.stroke();
        D.rect(ctx, 22, 205, 26, 190, green); D.rect(ctx, 198, 205, 26, 190, green);
        for (let i = 0; i < 6; i++) { const lift = i === 0 || i === 5 ? 0 : i === 1 || i === 4 ? 60 : 85; flower(ctx, 110 + i * 34 - 85, 285 - 180 - lift + 20); }
        D.text(ctx, 'GARDEN', 110, 165, 18, '#fff', 900);
      });
    },
    roofWindow(ctx, x, y) {
      at(ctx, x, y, 150, 170, () => {
        D.rrect(ctx, 75, 85, 150, 170, 8, darkWood);
        D.rrect(ctx, 75, 85, 124, 144, 4, SN.rgb(1, 0.85, 0.5));
        D.text(ctx, '↙', 75, 85, 44, darkWood, 900);
      });
    },
    owl(ctx, x, y, t) {
      at(ctx, x, y, 50, 280, () => {
        const brown = SN.rgb(0.50, 0.36, 0.22);
        D.ellipse(ctx, 25, 25, 40, 50, brown);
        D.tri(ctx, 12, -1, 12, 12, brown); D.tri(ctx, 38, -1, 12, 12, brown);
        const blink = ((t || SN.now()) % 2.5) < 0.2;
        D.circle(ctx, 16, 17, 13, '#ffcc00'); D.circle(ctx, 16, 17, 5, '#000');
        if (blink) D.capsule(ctx, 34, 17, 13, 3, '#ffcc00'); else { D.circle(ctx, 34, 17, 13, '#ffcc00'); D.circle(ctx, 34, 17, 5, '#000'); }
        D.tri(ctx, 25, 27, 8, 7, '#ff9500', false);
      });
    },
    phoneNightstand(ctx, x, y) {
      at(ctx, x, y, 96, 96, () => {
        ctx.save(); ctx.shadowColor = '#32ade6'; ctx.shadowBlur = 10;
        D.rrect(ctx, 48, 6, 34, 12, 4, SN.white(0.1)); D.rrect(ctx, 48, 6, 28, 6, 2, 'rgba(50,173,230,.7)');
        ctx.restore();
        D.rrect(ctx, 48, 54, 90, 84, 5, SN.rgb(0.55, 0.36, 0.24));
        D.capsule(ctx, 48, 38, 22, 6, SN.colors.gold);
      });
    },

    // ---------- On the floor ----------
    plank(ctx, x, y, w, h) {
      ctx.save(); ctx.translate(x, y); ctx.rotate(-3 * Math.PI / 180);
      D.rect(ctx, 0, 0, w, h, SN.rgb(0.72, 0.52, 0.32));
      ctx.strokeStyle = 'rgba(0,0,0,.5)'; ctx.lineWidth = 3; ctx.strokeRect(-w / 2, -h / 2, w, h);
      D.circle(ctx, -w / 2 + 10, -h / 2 + 9, 7, SN.white(0.8)); D.circle(ctx, w / 2 - 10, h / 2 - 9, 7, SN.white(0.8));
      ctx.strokeStyle = 'rgba(0,0,0,.45)'; ctx.lineWidth = 2; ctx.beginPath();
      ctx.moveTo(-w / 2 + w * 0.3, -h / 2); ctx.lineTo(-w / 2 + w * 0.55, 0); ctx.lineTo(-w / 2 + w * 0.4, h / 2); ctx.stroke();
      ctx.restore();
    },
    starBall(ctx, x, y, t) {
      const bob = 6 + 4 * Math.sin((t || SN.now()) * 4.5);
      const cy = y - 20 - bob;
      ctx.save(); ctx.shadowColor = '#ffcc00'; ctx.shadowBlur = 8 + bob * 1.4;
      const g = ctx.createRadialGradient(x, cy, 2, x, cy, 22); g.addColorStop(0, '#fff'); g.addColorStop(0.5, '#ffcc00'); g.addColorStop(1, '#ff9500');
      D.circle(ctx, x, cy, 40, g); ctx.restore();
      D.star(ctx, x, cy, 10, '#fff');
    },
    boostBall(ctx, x, y, t) {
      const bob = 7 + 5 * Math.sin((t || SN.now()) * 5);
      const cy = y - 22 - bob;
      ctx.save(); ctx.shadowColor = '#32ade6'; ctx.shadowBlur = 8 + bob * 1.5;
      const g = ctx.createRadialGradient(x, cy, 2, x, cy, 24); g.addColorStop(0, '#fff'); g.addColorStop(0.5, '#32ade6'); g.addColorStop(1, '#af52de');
      D.circle(ctx, x, cy, 44, g); ctx.restore();
      D.rrect(ctx, x, cy, 18, 16, 3, '#fff'); D.rect(ctx, x, cy, 4, 16, '#ff2d55'); D.rect(ctx, x, cy, 18, 4, '#ff2d55');
    },
    goldenStick(ctx, x, y, t) {
      ctx.save(); ctx.shadowColor = '#ffcc00'; ctx.shadowBlur = 14;
      D.text(ctx, '🪄', x, y - 26 - 4 * Math.sin((t || SN.now()) * 4), 40, SN.colors.gold); ctx.restore();
    },
    paintCans(ctx, x, y) {
      at(ctx, x, y, 70, 46, () => {
        [[18, '#007aff', 40], [52, '#ffcc00', 30]].forEach(([cx, c, h]) => {
          D.rrect(ctx, cx, 46 - h / 2, 30, h, 4, SN.white(0.75)); D.rect(ctx, cx, 46 - h + h * 0.35 + 5, 30, 10, c);
        });
      });
    },
    teddy(ctx, x, y, color = SN.rgb(0.70, 0.48, 0.30)) {
      D.circle(ctx, x, y + 14, 30, color); D.circle(ctx, x, y, 24, color);
      D.circle(ctx, x - 10, y - 10, 10, color); D.circle(ctx, x + 10, y - 10, 10, color);
      D.circle(ctx, x - 4, y - 2, 3, '#000'); D.circle(ctx, x + 4, y - 2, 3, '#000'); D.circle(ctx, x, y + 3, 4, 'rgba(0,0,0,.6)');
    },
    thrownToy(ctx, x, y) { D.rotated(ctx, x, y - 20, 80, () => P.teddy(ctx, 0, 0, SN.rgb(1, 0.55, 0.7))); },
  });
  const P = SN.props;
})();
