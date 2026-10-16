// Furniture and props for the rooms. Each draws with its bottom centre on (x, y), like the
// iPad version's anchored(at:). Shapes and colours follow HallwayArt.swift and friends.
(function () {
  const D = SN.draw;
  const wood = SN.rgb(0.55, 0.36, 0.22), darkWood = SN.rgb(0.42, 0.27, 0.17);

  /// Runs fn with (0, 0) at the bottom centre of a w × h box standing on (x, y); fn draws in that box.
  function at(ctx, x, y, w, h, fn) {
    ctx.save(); ctx.translate(x - w / 2, y - h); fn(w, h); ctx.restore();
  }

  const P = {
    // ---------- Walls ----------
    /// The hallway: striped wallpaper, a skirting board and a long red runner.
    hallwayWall(ctx, width) {
      const g = ctx.createLinearGradient(0, 0, 0, 545);
      g.addColorStop(0, SN.rgb(0.22, 0.18, 0.32)); g.addColorStop(1, SN.rgb(0.32, 0.25, 0.40));
      ctx.fillStyle = g; ctx.fillRect(0, 0, width, 545);
      for (let x = 0; x < width; x += 60) { ctx.fillStyle = 'rgba(255,255,255,.04)'; ctx.fillRect(x, 0, 30, 530); }
      ctx.fillStyle = SN.rgb(0.30, 0.20, 0.16); ctx.fillRect(0, 530, width, 16);
      const f = ctx.createLinearGradient(0, 545, 0, 700);
      f.addColorStop(0, SN.rgb(0.40, 0.28, 0.20)); f.addColorStop(1, SN.rgb(0.50, 0.35, 0.24));
      ctx.fillStyle = f; ctx.fillRect(0, 545, width, 155);
      ctx.fillStyle = SN.rgb(0.55, 0.15, 0.20); ctx.fillRect(80, 575, width - 160, 100);
      ctx.strokeStyle = SN.rgb(0.85, 0.65, 0.3); ctx.lineWidth = 4; ctx.strokeRect(92, 585, width - 184, 80);
      // Pictures every so often
      for (let i = 0, x = 420; x < width - 200; x += 760, i++) P.picture(ctx, x, 250, i);
    },
    siblingRoomWall(ctx, width) {
      const g = ctx.createLinearGradient(0, 0, 0, 545);
      g.addColorStop(0, SN.rgb(0.30, 0.32, 0.55)); g.addColorStop(1, SN.rgb(0.40, 0.38, 0.62));
      ctx.fillStyle = g; ctx.fillRect(0, 0, width, 545);
      const r = SN.seeded(4);
      for (let i = 0; i < 40; i++) D.star(ctx, r() * width, 40 + r() * 440, 6, 'rgba(255,255,255,.12)');
      // A rainbow over the bed
      ['#ff3b30', '#ff9500', '#ffcc00', '#34c759', '#007aff'].forEach((c, i) => {
        ctx.strokeStyle = c; ctx.lineWidth = 10; ctx.beginPath(); ctx.arc(1180, 300, 120 - i * 11, Math.PI, 0); ctx.stroke();
      });
      ctx.fillStyle = SN.rgb(0.30, 0.22, 0.18); ctx.fillRect(0, 530, width, 16);
      ctx.fillStyle = SN.rgb(0.58, 0.48, 0.36); ctx.fillRect(0, 545, width, 155);
      D.ellipse(ctx, 700, 640, 700, 90, SN.rgb(0.35, 0.65, 0.55), SN.rgb(0.9, 0.95, 0.85), 5);
    },
    momRoomWall(ctx, width) {
      const g = ctx.createLinearGradient(0, 0, 0, 545);
      g.addColorStop(0, SN.rgb(0.36, 0.22, 0.30)); g.addColorStop(1, SN.rgb(0.46, 0.30, 0.38));
      ctx.fillStyle = g; ctx.fillRect(0, 0, width, 545);
      for (let x = 30; x < width; x += 90) for (let y = 60; y < 500; y += 90) D.heart(ctx, x + (y % 180 ? 45 : 0), y, 14, 'rgba(255,255,255,.06)');
      ctx.fillStyle = SN.rgb(0.30, 0.18, 0.16); ctx.fillRect(0, 530, width, 16);
      ctx.fillStyle = SN.rgb(0.45, 0.30, 0.25); ctx.fillRect(0, 545, width, 155);
      D.ellipse(ctx, 900, 640, 720, 90, SN.rgb(0.75, 0.55, 0.65));
      // Window with curtains
      D.rrect(ctx, 600, 230, 200, 170, 8, SN.rgb(0.45, 0.30, 0.22));
      const sky = ctx.createLinearGradient(0, 160, 0, 300); sky.addColorStop(0, SN.palette.skyTop()); sky.addColorStop(1, SN.palette.skyBottom());
      ctx.fillStyle = sky; ctx.fillRect(515, 160, 170, 140);
      D.capsule(ctx, 490, 240, 30, 210, SN.rgb(0.6, 0.25, 0.4)); D.capsule(ctx, 710, 240, 30, 210, SN.rgb(0.6, 0.25, 0.4));
    },

    picture(ctx, x, y, seed) {
      D.rrect(ctx, x, y, 110, 86, 4, SN.colors.gold);
      const kinds = [['#5aa9e6', '😀'], ['#f4d58d', '🐶'], ['#9be3a6', '👨‍👩‍👦'], ['#c9a7f2', '🐱']];
      const [bg, face] = kinds[seed % kinds.length];
      D.rect(ctx, x, y, 92, 68, bg);
      ctx.font = '40px system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(face, x, y + 4);
    },

    // ---------- Doors and furniture against the wall ----------
    door(ctx, x, y, color, open, sign, signColor = '#ffcc00') {
      at(ctx, x, y, 104, 300, () => {
        D.rect(ctx, 52, 150, 104, 300, SN.rgb(0.95, 0.8, 0.5));
        ctx.save();
        ctx.translate(0, 0);
        const sx = open ? 0.15 : 1;
        ctx.scale(sx, 1);
        D.rrect(ctx, 52, 150, 104, 300, 6, color);
        D.rrect(ctx, 52, 82, 66, 110, 4, null, 'rgba(0,0,0,.2)', 4);
        D.rrect(ctx, 52, 213, 66, 120, 4, null, 'rgba(0,0,0,.2)', 4);
        D.circle(ctx, 86, 160, 14, SN.colors.gold);
        if (sign && !open) {
          ctx.save(); ctx.translate(52, 52); ctx.rotate(-4 * Math.PI / 180);
          ctx.font = '800 15px ui-rounded, system-ui'; const w = ctx.measureText(sign).width + 18;
          D.rrect(ctx, 0, 0, w, 26, 6, signColor); D.text(ctx, sign, 0, 1, 15, '#000', 800);
          ctx.restore();
        }
        ctx.restore();
        ctx.strokeStyle = SN.rgb(0.32, 0.2, 0.14); ctx.lineWidth = 10; ctx.strokeRect(0, 0, 104, 300);
      });
    },
    closet(ctx, x, y, hiding) {
      at(ctx, x, y, 140, 300, () => {
        D.rrect(ctx, 70, 150, 140, 300, 6, SN.rgb(0.50, 0.33, 0.22));
        D.rrect(ctx, 36, 150, 60, 280, 4, SN.rgb(0.58, 0.39, 0.26)); D.rrect(ctx, 104, 150, 60, 280, 4, SN.rgb(0.58, 0.39, 0.26));
        for (let i = 0; i < 9; i++) { D.rect(ctx, 36, 60 + i * 12, 44, 3, 'rgba(0,0,0,.25)'); D.rect(ctx, 104, 60 + i * 12, 44, 3, 'rgba(0,0,0,.25)'); }
        D.circle(ctx, 62, 160, 9, SN.colors.gold); D.circle(ctx, 78, 160, 9, SN.colors.gold);
        if (hiding) { D.circle(ctx, 58, 120, 12, '#fff'); D.circle(ctx, 58, 120, 6, '#000'); D.circle(ctx, 82, 120, 12, '#fff'); D.circle(ctx, 82, 120, 6, '#000'); }
      });
    },
    dresser(ctx, x, y, open) {
      at(ctx, x, y, 160, 130, () => {
        D.rrect(ctx, 80, 65, 160, 130, 6, wood);
        for (let i = 0; i < 3; i++) {
          D.rrect(ctx, 80 + (open && i === 0 ? 0 : 0), 24 + i * 40, 140, 32, 4, SN.shade(wood, 0.1));
          D.capsule(ctx, 80, 24 + i * 40, 28, 6, SN.colors.gold);
        }
        if (open) D.rrect(ctx, 80, 10, 150, 18, 3, SN.shade(wood, 0.2));
        D.rrect(ctx, 80, -12, 36, 30, 3, SN.colors.gold); D.text(ctx, '🐶', 80, -12, 18, '#000');
      });
    },
    nightstand(ctx, x, y, open) {
      at(ctx, x, y, 110, 120, () => {
        D.rrect(ctx, 55, 60, 110, 120, 6, wood);
        D.rrect(ctx, 55, 40, 90, 30, 4, SN.shade(wood, 0.1)); D.capsule(ctx, 55, 40, 24, 6, SN.colors.gold);
        if (open) D.rrect(ctx, 55, 18, 96, 16, 3, SN.shade(wood, 0.2));
        D.rrect(ctx, 30, -14, 22, 30, 4, '#ffcc00');
      });
    },
    window(ctx, x, y, open, keyTaken) {
      at(ctx, x, y, 220, 300, () => {
        D.rrect(ctx, 110, 130, 220, 200, 8, SN.rgb(0.45, 0.3, 0.22));
        const sky = ctx.createLinearGradient(0, 40, 0, 220); sky.addColorStop(0, SN.palette.skyTop()); sky.addColorStop(1, SN.palette.skyBottom());
        ctx.fillStyle = sky; ctx.fillRect(15, 45, 190, 170);
        D.circle(ctx, 150, 90, 44, SN.palette.moon());
        if (!open) { D.rect(ctx, 110, 130, 8, 170, SN.rgb(0.45, 0.3, 0.22)); D.rect(ctx, 110, 130, 190, 8, SN.rgb(0.45, 0.3, 0.22)); }
        else { ctx.fillStyle = 'rgba(200,230,255,.25)'; ctx.fillRect(15, 45, 50, 170); }
        D.rect(ctx, 110, 236, 240, 14, SN.rgb(0.55, 0.4, 0.3));
        if (!keyTaken) { ctx.save(); ctx.shadowColor = '#fff'; ctx.shadowBlur = open ? 14 : 4; D.key(ctx, 160, 222, 28, SN.colors.silver); ctx.restore(); }
      });
    },
    exitDoor(ctx, x, y, open, codeAccepted) {
      P.door(ctx, x, y, SN.rgb(0.25, 0.45, 0.35), open, codeAccepted ? 'CODE OK' : 'EXIT', codeAccepted ? '#34c759' : '#ffcc00');
      if (!open) { D.rrect(ctx, x + 40, y - 190, 26, 34, 4, SN.white(0.2)); D.text(ctx, '🔒', x + 40, y - 190, 14, '#fff'); }
    },
    siblingBed(ctx, x, y, empty) {
      at(ctx, x, y, 280, 170, () => {
        D.rrect(ctx, 14, 85, 22, 170, 8, darkWood); D.rrect(ctx, 266, 110, 18, 120, 8, darkWood);
        D.rect(ctx, 140, 118, 260, 22, wood);
        D.rrect(ctx, 140, 96, 250, 30, 10, '#fff');
        D.capsule(ctx, 52, 72, 70, 30, SN.rgb(0.92, 0.92, 1));
        const g = ctx.createLinearGradient(0, 70, 0, 120); g.addColorStop(0, SN.rgb(0.95, 0.55, 0.3)); g.addColorStop(1, SN.rgb(0.85, 0.35, 0.3));
        D.rrect(ctx, 160, 92, 190, 44, 14, g);
        if (!empty) {
          D.circle(ctx, 58, 62, 40, SN.rgb(0.96, 0.78, 0.62));
          D.dome(ctx, 58, 58, 44, 40, SN.rgb(0.33, 0.21, 0.12));
          D.capsule(ctx, 50, 64, 8, 2, '#000'); D.capsule(ctx, 66, 64, 8, 2, '#000');
          D.text(ctx, 'z Z z', 100, 18, 18, 'rgba(255,255,255,.8)');
        }
      });
    },
    toyChest(ctx, x, y) {
      at(ctx, x, y, 120, 110, () => {
        D.circle(ctx, 40, 22, 30, SN.rgb(0.7, 0.48, 0.3)); D.circle(ctx, 84, 20, 22, '#ff3b30');
        D.rrect(ctx, 60, 70, 120, 80, 8, SN.rgb(0.95, 0.6, 0.25));
        D.text(ctx, 'TOYS', 60, 72, 18, '#fff', 900);
      });
    },
    paperStack(ctx, x, y) {
      at(ctx, x, y, 90, 70, () => {
        for (let i = 0; i < 4; i++) D.rrect(ctx, 40, 64 - i * 6, 62, 8, 2, SN.rgb(1, 0.98, 0.92));
        ['#ff3b30', '#007aff', '#34c759', '#ff9500'].forEach((c, i) => D.rotated(ctx, 64 + i * 6, 24, (i - 1) * 9, () => D.capsule(ctx, 0, 0, 6, 30, c)));
      });
    },
    vanity(ctx, x, y, open) {
      at(ctx, x, y, 150, 240, () => {
        D.ellipse(ctx, 75, 60, 90, 110, SN.rgb(0.75, 0.85, 0.95), SN.colors.gold, 6);
        D.rrect(ctx, 75, 190, 150, 100, 8, SN.rgb(0.95, 0.85, 0.9));
        D.rrect(ctx, 75, 140, 50, 26, 6, open ? SN.rgb(0.8, 0.3, 0.5) : SN.rgb(0.9, 0.45, 0.65));
        if (!open) D.circle(ctx, 75, 140, 8, SN.colors.gold);
      });
    },
    momBed(ctx, x, y, empty) {
      at(ctx, x, y, 300, 190, () => {
        D.rrect(ctx, 150, 30, 300, 70, 20, SN.rgb(0.55, 0.3, 0.35));
        D.rect(ctx, 150, 150, 290, 30, wood);
        D.rrect(ctx, 150, 120, 290, 40, 12, '#fff');
        D.capsule(ctx, 70, 92, 80, 30, SN.rgb(0.95, 0.92, 1)); D.capsule(ctx, 230, 92, 80, 30, SN.rgb(0.95, 0.92, 1));
        D.rrect(ctx, 165, 118, 250, 50, 16, SN.rgb(0.85, 0.5, 0.65));
        if (!empty) { D.circle(ctx, 70, 82, 44, SN.rgb(0.96, 0.8, 0.66)); D.dome(ctx, 70, 78, 50, 44, SN.rgb(0.45, 0.28, 0.15)); D.text(ctx, 'z z z', 120, 40, 18, 'rgba(255,255,255,.8)'); }
        D.rect(ctx, 150, 186, 220, 8, 'rgba(0,0,0,.5)');
      });
    },
    alarmNightstand(ctx, x, y, turnedBack) {
      P.nightstand(ctx, x, y, false);
      D.rrect(ctx, x + 22, y - 140, 40, 34, 8, turnedBack ? '#34c759' : '#ff3b30');
      D.text(ctx, turnedBack ? '+30' : '⏰', x + 22, y - 140, 15, '#fff');
    },
    dadDesk(ctx, x, y) {
      at(ctx, x, y, 140, 110, () => {
        D.rect(ctx, 70, 30, 140, 14, wood); D.rect(ctx, 14, 72, 10, 76, darkWood); D.rect(ctx, 126, 72, 10, 76, darkWood);
        D.rrect(ctx, 40, 14, 22, 24, 4, '#fff'); D.rect(ctx, 90, 16, 50, 10, SN.white(0.85));
      });
    },

    // ---------- Things on the floor ----------
    box(ctx, x, y, open) {
      at(ctx, x, y, 80, 60, () => {
        D.rrect(ctx, 40, 32, 76, 50, 4, SN.rgb(0.72, 0.53, 0.33));
        D.rect(ctx, 40, 32, 8, 50, SN.rgb(0.6, 0.42, 0.25));
        if (open) { D.rotated(ctx, 4, 8, -30, () => D.rect(ctx, 18, 0, 36, 8, SN.rgb(0.78, 0.6, 0.4))); D.rotated(ctx, 76, 8, 30, () => D.rect(ctx, -18, 0, 36, 8, SN.rgb(0.78, 0.6, 0.4))); }
      });
    },
    chair(ctx, x, y) {
      at(ctx, x, y, 80, 120, () => {
        D.rect(ctx, 16, 50, 8, 100, darkWood); D.rect(ctx, 16, 20, 8, 40, darkWood);
        D.rect(ctx, 40, 70, 64, 10, wood); D.rect(ctx, 64, 96, 8, 50, darkWood);
        D.rect(ctx, 36, 64, 50, 8, '#ff3b30');
      });
    },
    floorLamp(ctx, x, y) {
      at(ctx, x, y, 70, 220, () => {
        ctx.save(); ctx.shadowColor = '#ffcc00'; ctx.shadowBlur = 20;
        ctx.beginPath(); ctx.moveTo(22, 0); ctx.lineTo(48, 0); ctx.lineTo(62, 40); ctx.lineTo(8, 40); ctx.closePath(); ctx.fillStyle = SN.rgb(0.95, 0.85, 0.6); ctx.fill();
        ctx.restore();
        D.rect(ctx, 35, 130, 6, 180, SN.white(0.25)); D.capsule(ctx, 35, 216, 44, 9, SN.white(0.25));
      });
    },
    sideTable(ctx, x, y) {
      at(ctx, x, y, 120, 90, () => {
        D.rrect(ctx, 60, 10, 120, 14, 4, wood); D.rect(ctx, 10, 52, 8, 76, darkWood); D.rect(ctx, 110, 52, 8, 76, darkWood);
        D.circle(ctx, 40, -4, 20, '#ff2d55'); D.rect(ctx, 70, -2, 14, 14, SN.rgb(0.3, 0.6, 0.85));
      });
    },
    shoes(ctx, x, y) { D.capsule(ctx, x - 14, y - 8, 34, 16, SN.rgb(0.35, 0.22, 0.15)); D.capsule(ctx, x + 16, y - 6, 34, 16, SN.rgb(0.35, 0.22, 0.15)); },
    basket(ctx, x, y) {
      at(ctx, x, y, 70, 50, () => {
        D.rrect(ctx, 35, 28, 64, 40, 8, SN.rgb(0.85, 0.75, 0.55));
        for (let i = 0; i < 4; i++) D.rect(ctx, 35, 14 + i * 9, 60, 2, 'rgba(0,0,0,.15)');
        D.circle(ctx, 22, 8, 18, '#5ac8fa'); D.circle(ctx, 46, 6, 16, '#ff9500');
      });
    },
    blocks(ctx, x, y) {
      D.rrect(ctx, x - 14, y - 12, 22, 22, 3, '#ff3b30'); D.text(ctx, 'A', x - 14, y - 12, 13, '#fff');
      D.rrect(ctx, x + 10, y - 12, 22, 22, 3, '#007aff'); D.text(ctx, 'B', x + 10, y - 12, 13, '#fff');
      D.rrect(ctx, x - 2, y - 34, 22, 22, 3, '#34c759'); D.text(ctx, 'C', x - 2, y - 34, 13, '#fff');
    },
    duck(ctx, x, y) { D.ellipse(ctx, x, y - 10, 34, 20, '#ffcc00'); D.circle(ctx, x + 12, y - 24, 16, '#ffcc00'); D.tri(ctx, x + 23, y - 22, 8, 6, '#ff9500'); D.circle(ctx, x + 14, y - 27, 3, '#000'); },
    toyCar(ctx, x, y, right) {
      ctx.save(); ctx.translate(x, y); ctx.scale(right ? 1 : -1, 1);
      D.rrect(ctx, 0, -18, 56, 20, 6, '#ff3b30'); D.rrect(ctx, -4, -30, 28, 14, 5, '#ff6b5e');
      D.circle(ctx, -16, -6, 14, '#222'); D.circle(ctx, 16, -6, 14, '#222');
      ctx.restore();
    },
    toyBall(ctx, x, y, t) {
      ctx.save(); ctx.translate(x, y - 16); ctx.rotate((t || SN.now()) * 6);
      ctx.beginPath(); ctx.arc(0, 0, 16, 0, Math.PI); ctx.fillStyle = '#007aff'; ctx.fill();
      ctx.beginPath(); ctx.arc(0, 0, 16, Math.PI, Math.PI * 2); ctx.fillStyle = '#ff9500'; ctx.fill();
      ctx.restore();
    },
    toyRobot(ctx, x, y) {
      D.rrect(ctx, x, y - 16, 30, 26, 4, SN.white(0.7)); D.rrect(ctx, x, y - 38, 24, 18, 4, SN.white(0.6));
      D.circle(ctx, x - 5, y - 39, 5, '#ff3b30'); D.circle(ctx, x + 5, y - 39, 5, '#ff3b30'); D.rect(ctx, x, y - 52, 2, 10, SN.white(0.5));
    },
    sparkle(ctx, x, y, t) { const a = 0.4 + 0.6 * Math.abs(Math.sin((t || SN.now()) * 4)); D.star(ctx, x, y, 12, `rgba(255,255,255,${a})`); },
  };
  SN.props = P;
})();
