// Drawings for Level 4: the hedge maze (seen from above) and the garden beyond the gate.
// Props draw with their bottom centre on (x, y). (A port of GardenArt.swift.)
(function () {
  const D = SN.draw;
  const leaf = SN.rgb(0.16, 0.46, 0.24), darkLeaf = SN.rgb(0.10, 0.32, 0.17);
  const brownWood = SN.rgb(0.42, 0.27, 0.17);

  function at(ctx, x, y, w, h, fn) { ctx.save(); ctx.translate(x - w / 2, y - h); fn(w, h); ctx.restore(); }
  /// A trapezoid wider at the top (flower pots, wheelbarrows).
  function pot(ctx, cx, top, w, h, fill, narrow = 0.7) {
    ctx.beginPath(); ctx.moveTo(cx - w / 2, top); ctx.lineTo(cx + w / 2, top);
    ctx.lineTo(cx + w * narrow / 2, top + h); ctx.lineTo(cx - w * narrow / 2, top + h); ctx.closePath();
    ctx.fillStyle = fill; ctx.fill();
  }
  function flower(ctx, x, y) {
    D.rect(ctx, x, y + 12, 3, 14, SN.rgb(0.2, 0.6, 0.3));
    for (let i = 0; i < 5; i++) { const a = i * 72 * Math.PI / 180; D.circle(ctx, x + Math.sin(a) * 7, y - Math.cos(a) * 7, 10, '#ff2d55'); }
    D.circle(ctx, x, y, 8, '#ffcc00');
  }

  Object.assign(SN.props, {
    /// The lawn under the maze, with a hedge border all the way round.
    mazeGround(ctx, w, h) {
      ctx.fillStyle = darkLeaf; ctx.fillRect(0, 0, w, h);
      const lx = 60, ly = 150, lw = w - 120, lh = h - 240;
      ctx.fillStyle = SN.rgb(0.45, 0.68, 0.36); ctx.fillRect(lx, ly, lw, lh);
      ctx.fillStyle = 'rgba(0,0,0,.06)';
      for (let x = lx + 110; x < lx + lw; x += 220) ctx.fillRect(x, ly, Math.min(110, lx + lw - x), lh);
      for (let bx = 20; bx < w; bx += 58) { D.ellipse(ctx, bx + 35, 126, 70, 60, leaf); D.ellipse(ctx, bx + 35, h - 66, 70, 60, leaf); }
    },
    /// A hedge wall: `w × h` is the ground it covers; it's drawn taller so it looks solid. (x, y) is its middle.
    hedge(ctx, x, y, w, h) {
      const top = y - h / 2 - 44;
      D.rrect(ctx, x, top + (h + 44) / 2, w, h + 44, 12, darkLeaf);
      D.rrect(ctx, x, top + (h + 6) / 2, w, h + 6, 12, leaf);
      D.rrect(ctx, x, top + 4 + h / 2 - 1, w - 8, h - 2, 10, null, 'rgba(255,255,255,.08)', 3);
    },
    plant(ctx, x, y, watered) {
      at(ctx, x, y, 44, 64, () => {
        pot(ctx, 22, 46, 30, 18, SN.rgb(0.70, 0.40, 0.25));
        if (watered) {
          D.rect(ctx, 22, 33, 4, 30, SN.rgb(0.2, 0.7, 0.3));
          flower(ctx, 22, 18);
          D.ellipse(ctx, 31, 31, 14, 7, SN.rgb(0.2, 0.7, 0.3));
        } else {
          D.rotated(ctx, 22, 48, 28, () => D.capsule(ctx, 0, -11, 4, 22, SN.rgb(0.55, 0.45, 0.22)));
          D.ellipse(ctx, 36, 30, 14, 8, SN.rgb(0.60, 0.48, 0.20));
        }
      });
    },
    pest(ctx, x, y, t) {
      D.rotated(ctx, x, y - 40, 12 * Math.sin((t || SN.now()) * 10), () => {
        D.ellipse(ctx, 0, 0, 28, 20, SN.rgb(0.75, 0.15, 0.15)); D.rect(ctx, 0, 0, 2, 20, '#000');
        D.circle(ctx, 14, 0, 10, '#000'); D.circle(ctx, -6, -4, 5, '#000'); D.circle(ctx, -6, 4, 5, '#000');
      });
    },
    spikyVine(ctx, x, y, w, h) {
      D.rrect(ctx, x, y, w, h, 8, 'rgba(64,31,77,.85)');
      ctx.fillStyle = SN.rgb(0.75, 0.30, 0.80);
      const across = w > h, long = Math.max(w, h);
      let flip = false;
      for (let d = 8; d < long - 6; d += 16) {
        const px = across ? x - w / 2 + d : x + (flip ? -5 : 5), py = across ? y + (flip ? -5 : 5) : y - h / 2 + d;
        ctx.beginPath(); ctx.moveTo(px - 6, py + 6); ctx.lineTo(px, py - 9); ctx.lineTo(px + 6, py + 6); ctx.closePath(); ctx.fill();
        flip = !flip;
      }
    },
    bush(ctx, x, y, hiding, strange, scale = 1) {
      ctx.save(); ctx.translate(x, y); ctx.scale(scale, scale);
      at(ctx, 0, 0, 110, 76, () => {
        const side = strange ? SN.rgb(0.20, 0.60, 0.45) : leaf;
        D.circle(ctx, 31, 44, 54, side); D.circle(ctx, 79, 44, 54, side);
        D.circle(ctx, 55, 30, 64, strange ? SN.rgb(0.26, 0.70, 0.52) : SN.rgb(0.20, 0.54, 0.28));
        if (strange) { D.star(ctx, 81, 8, 9, '#ffcc00'); D.rotated(ctx, 21, 60, 30, () => D.capsule(ctx, 0, 0, 5, 26, SN.rgb(0.1, 0.4, 0.2))); }
        if (hiding) { [47, 63].forEach(ex => { D.circle(ctx, ex, 32, 10, '#fff'); D.circle(ctx, ex, 32, 4, '#000'); }); }
      });
      ctx.restore();
    },
    radarStation(ctx, x, y, t) {
      at(ctx, x, y, 70, 100, () => {
        D.rect(ctx, 35, 75, 8, 50, SN.white(0.4));
        D.rrect(ctx, 35, 34, 60, 44, 8, SN.white(0.2));
        D.circle(ctx, 35, 34, 30, null, 'rgba(52,199,89,.7)', 2);
        D.rotated(ctx, 35, 34, ((t || SN.now()) * 120) % 360, () => D.rect(ctx, 0, -7.5, 2, 15, '#34c759'));
      });
    },
    mazeGate(ctx, x, y, open, dogs, t) {
      at(ctx, x, y, 110, 124, () => {
        D.rect(ctx, 16, 69, 14, 110, SN.rgb(0.50, 0.32, 0.20)); D.rect(ctx, 94, 69, 14, 110, SN.rgb(0.50, 0.32, 0.20));
        for (let i = 0; i < 5; i++) D.rrect(ctx, 37 + i * 13, 81, 8, 86, 3, open ? SN.rgb(0.55, 0.80, 0.45) : SN.rgb(0.70, 0.60, 0.45));
        D.text(ctx, open ? '🔓' : '🔒', 55, 22, 18, '#fff');
      });
      if (dogs) {
        SN.props.dog(ctx, x - 135, y + 6, false, t, 0.5);
        ctx.save(); ctx.translate(x - 85, 0); ctx.scale(-1, 1); SN.props.dog(ctx, 0, y + 6, false, t, 0.5); ctx.restore();
      }
    },

    // ---------- Beyond the gate ----------
    beyondScene(ctx, width) {
      const g = ctx.createLinearGradient(0, 0, 0, 460); g.addColorStop(0, SN.palette.skyTop()); g.addColorStop(1, SN.rgb(0.20, 0.18, 0.45));
      ctx.fillStyle = g; ctx.fillRect(0, 0, width, 460);
      for (let i = 0; i < 50; i++) D.circle(ctx, (i * 173) % width, (i * 61) % 250, 2 + i % 3, `rgba(255,255,255,${0.8 * Math.max(SN.palette.starlight(), 0.15)})`);
      ctx.save(); ctx.shadowColor = SN.palette.moon(); ctx.shadowBlur = 26; D.circle(ctx, 1500, 110, 90, SN.palette.moon()); ctx.restore();
      for (let x = 0; x < width; x += 44) D.rrect(ctx, x + 17, 375, 34, 170, 4, SN.rgb(0.62, 0.56, 0.48));
      const f = ctx.createLinearGradient(0, 458, 0, 700); f.addColorStop(0, SN.rgb(0.10, 0.30, 0.18)); f.addColorStop(1, SN.rgb(0.15, 0.40, 0.23));
      ctx.fillStyle = f; ctx.fillRect(0, 458, width, 242);
    },
    flowerPots(ctx, x, y) {
      P.plant(ctx, x - 50, y, true);
      ctx.save(); ctx.translate(x, y); ctx.scale(1.3, 1.3); P.plant(ctx, 0, 0, true); ctx.restore();
      P.plant(ctx, x + 50, y, true);
    },
    wheelbarrow(ctx, x, y) {
      at(ctx, x, y, 170, 100, () => {
        D.circle(ctx, 39, 82, 36, SN.white(0.15));
        pot(ctx, 85, 24, 110, 50, SN.rgb(0.75, 0.25, 0.2), 0.6);
        D.rotated(ctx, 149, 48, -14, () => D.rect(ctx, 0, 0, 70, 7, SN.rgb(0.5, 0.32, 0.2)));
        D.ellipse(ctx, 85, 30, 90, 22, SN.rgb(0.35, 0.22, 0.12));
      });
    },
    birdhouse(ctx, x, y) {
      at(ctx, x, y, 70, 240, () => {
        D.tri(ctx, 35, 15, 70, 30, SN.rgb(0.7, 0.2, 0.2));
        D.rect(ctx, 35, 55, 54, 50, SN.rgb(0.85, 0.70, 0.45)); D.circle(ctx, 35, 55, 20, '#000');
        D.rect(ctx, 35, 160, 8, 160, brownWood);
      });
    },
    well(ctx, x, y) {
      at(ctx, x, y, 160, 220, () => {
        D.rect(ctx, 27, 135, 10, 170, brownWood); D.rect(ctx, 133, 135, 10, 170, brownWood);
        D.tri(ctx, 80, 35, 150, 50, SN.rgb(0.55, 0.25, 0.2));
        D.rrect(ctx, 80, 185, 130, 70, 8, SN.white(0.55));
        for (let i = 0; i < 3; i++) D.rect(ctx, 80, 220 - (i * 22 + 12), 130, 2, 'rgba(0,0,0,.2)');
        D.rect(ctx, 80, 95, 3, 70, SN.white(0.85));
        D.rrect(ctx, 80, 136, 26, 24, 3, SN.rgb(0.5, 0.32, 0.2));
      });
    },
    compost(ctx, x, y) {
      at(ctx, x, y, 104, 122, () => {
        D.rrect(ctx, 52, 67, 96, 110, 8, SN.rgb(0.18, 0.30, 0.20));
        D.rrect(ctx, 52, 14, 104, 16, 6, SN.rgb(0.12, 0.22, 0.14));
        D.text(ctx, '🍃', 52, 70, 30, '#34c759');
      });
    },
    scarecrow(ctx, x, y) {
      at(ctx, x, y, 160, 260, () => {
        D.rect(ctx, 80, 145, 8, 230, SN.rgb(0.5, 0.36, 0.2));
        D.rect(ctx, 80, 106, 150, 8, SN.rgb(0.5, 0.36, 0.2));
        D.rrect(ctx, 80, 120, 70, 80, 8, SN.rgb(0.75, 0.30, 0.25));
        D.circle(ctx, 80, 56, 52, SN.rgb(0.92, 0.80, 0.50));
        D.text(ctx, 'x', 69, 64, 14, '#000', 900); D.text(ctx, 'x', 91, 64, 14, '#000', 900);
        ctx.beginPath(); ctx.moveTo(43 + 10, 25); ctx.lineTo(117 - 10, 25); ctx.lineTo(117, 51); ctx.lineTo(43, 51); ctx.closePath();
        ctx.fillStyle = SN.rgb(0.45, 0.32, 0.16); ctx.fill();
      });
    },
    streetGate(ctx, x, y, open, codeAccepted) {
      at(ctx, x - 35, y, 130, 290, () => {
        D.rect(ctx, 65, 145, 130, 290, SN.rgb(0.12, 0.12, 0.2));
        const sx = open ? 0.15 : 1;
        for (let i = 0; i < 6; i++) D.rrect(ctx, 5 + (i * 18 + 15) * sx, 145, 8 * sx, 260, 3, SN.white(0.2));
        if (!open) for (let i = 0; i < 3; i++) D.text(ctx, '🔒', 65, 110 + i * 36, 20, '#fff');
        ctx.strokeStyle = SN.white(0.25); ctx.lineWidth = 10; ctx.strokeRect(0, 0, 130, 290);
      });
      D.rrect(ctx, x + 72, y - 145, 44, 46, 8, SN.white(0.2));
      D.circle(ctx, x + 72, y - 155, 12, codeAccepted ? '#34c759' : '#ff3b30');
      D.text(ctx, 'ABC', x + 72, y - 136, 12, '#fff', 900);
    },
  });
  const P = SN.props;
})();
