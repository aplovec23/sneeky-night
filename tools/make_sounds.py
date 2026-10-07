"""Synthesizes the game's sound effects into SneekyNight/Sounds/*.wav.
Run: python3 tools/make_sounds.py
"""
import math, random, struct, wave, os

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "SneekyNight", "Sounds")
random.seed(3)

def env(i, n, attack=0.005, curve=4.0):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-curve * i / n)

def tone(f0, dur, vol=0.5, f1=None, shape="sine", curve=4.0, vib=0.0, attack=0.005):
    n = int(dur * RATE); f1 = f1 or f0; out = []; ph = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        if vib: f *= 1 + 0.03 * math.sin(2 * math.pi * vib * i / RATE)
        ph += 2 * math.pi * f / RATE
        if shape == "sine": s = math.sin(ph)
        elif shape == "square": s = 0.6 if math.sin(ph) > 0 else -0.6
        elif shape == "saw": s = ((ph / math.pi) % 2) - 1
        else: s = 2 * abs(((ph / math.pi) % 2) - 1) - 1  # triangle
        out.append(s * vol * env(i, n, attack, curve))
    return out

def noise(dur, vol=0.5, smooth=0.5, curve=4.0, attack=0.002):
    n = int(dur * RATE); out = []; y = 0.0
    for i in range(n):
        y = smooth * y + (1 - smooth) * random.uniform(-1, 1)
        out.append(y * vol * env(i, n, attack, curve))
    return out

def silence(dur): return [0.0] * int(dur * RATE)

def mix(*parts):
    n = max(len(p) for p in parts); out = [0.0] * n
    for p in parts:
        for i, s in enumerate(p): out[i] += s
    return out

def cat(*parts):
    out = []
    for p in parts: out += p
    return out

def save(name, data):
    peak = max(1e-6, max(abs(s) for s in data))
    scale = min(1.0, 0.95 / peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in data))

os.makedirs(OUT, exist_ok=True)
save("click", mix(tone(1500, 0.04, 0.5, curve=9), noise(0.015, 0.2, 0.2, curve=8)))
save("step", noise(0.07, 0.35, 0.85, curve=6))
save("jump", tone(300, 0.2, 0.5, f1=750, curve=2.5))
save("land", mix(noise(0.09, 0.5, 0.9, curve=6), tone(90, 0.09, 0.5, curve=6)))
save("key", cat(tone(1175, 0.08, 0.4, curve=2), tone(1568, 0.08, 0.4, curve=2), tone(2093, 0.3, 0.4, curve=4)))
save("powerup", cat(*[tone(f, 0.07, 0.4, shape="square", curve=2) for f in (523, 659, 784, 1047, 1319)], tone(1568, 0.25, 0.35, shape="square")))
save("drawer", cat(mix(noise(0.35, 0.5, 0.92, curve=1.5), tone(70, 0.35, 0.2, curve=1)), noise(0.03, 0.5, 0.3, curve=8)))
save("box", cat(noise(0.08, 0.6, 0.6), noise(0.06, 0.5, 0.6), noise(0.12, 0.5, 0.7)))
save("paper", cat(*[noise(0.04 + random.random() * 0.03, 0.4, 0.1, curve=5) for _ in range(6)]))
save("window", tone(180, 0.55, 0.25, f1=260, shape="saw", curve=1.5, vib=11))
save("door", tone(130, 0.8, 0.25, f1=85, shape="saw", curve=1.2, vib=9))
save("closet", tone(220, 0.3, 0.25, f1=160, shape="saw", curve=2, vib=13))
save("unlock", cat(mix(noise(0.03, 0.6, 0.2, curve=9), tone(2000, 0.05, 0.3, curve=8)), silence(0.08),
                   mix(noise(0.04, 0.7, 0.3, curve=9), tone(1500, 0.08, 0.3, curve=6))))
save("buzz", tone(140, 0.45, 0.4, shape="square", curve=1))
save("beep", tone(1200, 0.07, 0.4, curve=3))
save("chair", mix(noise(0.55, 0.6, 0.55, curve=1.2), tone(400, 0.55, 0.15, f1=250, shape="saw", vib=25, curve=1.2)))
save("table", mix(tone(65, 0.45, 0.8, curve=5), noise(0.12, 0.5, 0.9, curve=7)))
save("lamp", mix(noise(0.7, 0.6, 0.15, curve=3), *[cat(silence(random.random() * 0.3), tone(random.choice((2600, 3100, 3700, 4200)), 0.12, 0.25, curve=6)) for _ in range(6)]))
save("squeak", cat(tone(1300, 0.12, 0.5, f1=2100, vib=18, curve=0.5), tone(2100, 0.14, 0.5, f1=1200, vib=18, curve=2)))
save("caught", cat(*[tone(f, 0.28, 0.45, shape="tri", vib=6, curve=0.8) for f in (392, 370, 349)], tone(330, 0.8, 0.45, shape="tri", vib=6, curve=1.5)))
save("mom", cat(tone(660, 0.22, 0.45, shape="square", curve=1), silence(0.05), tone(440, 0.4, 0.45, shape="square", curve=1.5)))
save("win", cat(*[tone(f, 0.12, 0.4, shape="square", curve=1.5) for f in (523, 659, 784)], mix(tone(1047, 0.6, 0.3, shape="square"), tone(784, 0.6, 0.2, shape="square"), tone(659, 0.6, 0.2, shape="square"))))
save("tick", tone(2500, 0.025, 0.4, curve=10))
save("heavy", mix(tone(110, 0.3, 0.4, f1=90, shape="saw", curve=2, vib=7), noise(0.3, 0.2, 0.9, curve=2)))
save("taunt", cat(*[tone(f, 0.16, 0.4, shape="square", vib=8, curve=1.2) for f in (660, 550, 660, 550)], tone(700, 0.3, 0.4, shape="square", vib=10, curve=2)))
save("dash", mix(noise(0.3, 0.6, 0.4, curve=3, attack=0.03), tone(900, 0.3, 0.15, f1=300, curve=3)))
save("dad", cat(*[cat(mix(tone(55, 0.14, 0.9, curve=6), noise(0.08, 0.4, 0.9, curve=8)), silence(0.32)) for _ in range(4)]))
save("crouch", noise(0.18, 0.35, 0.6, curve=3, attack=0.03))
save("magic", cat(*[tone(f, 0.06, 0.3, curve=2) for f in (1047, 1319, 1568, 2093, 1568, 2093, 2637)], tone(3136, 0.3, 0.3, curve=4)))
save("woof", cat(mix(tone(320, 0.12, 0.6, f1=180, shape="saw", curve=2), noise(0.12, 0.3, 0.7, curve=3)), silence(0.1), mix(tone(340, 0.16, 0.6, f1=170, shape="saw", curve=2), noise(0.16, 0.3, 0.7, curve=3))))
save("creak", tone(300, 0.7, 0.4, f1=520, shape="saw", curve=1.0, vib=17))
save("craft", cat(*[cat(mix(tone(1800, 0.05, 0.4, curve=8), noise(0.05, 0.6, 0.3, curve=8)), silence(0.14)) for _ in range(4)], tone(1568, 0.25, 0.3, curve=3)))
save("lightSwitch", cat(noise(0.02, 0.7, 0.2, curve=9), silence(0.03), tone(900, 0.03, 0.3, curve=9)))
save("star", cat(tone(1568, 0.06, 0.35, curve=2), tone(2093, 0.06, 0.35, curve=2), tone(2637, 0.2, 0.35, curve=4)))
save("ouch", cat(tone(700, 0.1, 0.5, f1=1100, shape="saw", curve=1), tone(1100, 0.25, 0.5, f1=500, shape="saw", vib=14, curve=2)))
save("water", mix(noise(0.35, 0.35, 0.3, curve=2, attack=0.05), tone(1400, 0.35, 0.08, f1=900, vib=30, curve=2)))
save("bug", cat(*[tone(2400 + 300 * (i % 2), 0.035, 0.3, shape="square", curve=2) for i in range(6)]))
save("rustle", cat(noise(0.1, 0.45, 0.25, curve=3), noise(0.14, 0.4, 0.3, curve=3)))
save("whip", cat(noise(0.16, 0.5, 0.5, curve=1, attack=0.1), mix(noise(0.05, 0.9, 0.05, curve=8), tone(1800, 0.06, 0.4, curve=8))))
save("bonk", mix(tone(180, 0.18, 0.7, f1=90, curve=5), noise(0.05, 0.6, 0.5, curve=8), tone(900, 0.08, 0.2, curve=6)))

# Background music: a slow, quiet lullaby loop (4 chords, 16 beats).
def music():
    beat = 0.72
    chords = [(261.6, 329.6, 392.0), (220.0, 261.6, 329.6), (174.6, 220.0, 261.6), (196.0, 246.9, 293.7)]
    melody = [523.3, 0, 659.3, 587.3, 523.3, 0, 440.0, 493.9, 440.0, 0, 349.2, 392.0, 392.0, 493.9, 587.3, 0]
    total = int(beat * 16 * RATE)
    out = [0.0] * total
    def add(start, samples):
        for i, s in enumerate(samples):
            if start + i < total: out[start + i] += s
    for c, chord in enumerate(chords):
        for b in range(4):
            start = int((c * 4 + b) * beat * RATE)
            note = chord[b % 3] / 2
            add(start, tone(note, beat * 1.6, 0.16, shape="tri", curve=2.2, attack=0.03))
        add(int(c * 4 * beat * RATE), tone(chord[0] / 4, beat * 4, 0.14, curve=1.2, attack=0.2))
    for n, f in enumerate(melody):
        if f: add(int(n * beat * RATE), tone(f, beat * 1.4, 0.11, curve=3, attack=0.02, vib=4))
    return out
save("music", music())
print("sounds written:", len(os.listdir(OUT)))
