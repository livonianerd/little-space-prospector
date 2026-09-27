"""Original deterministic score: 32s circular ambient waltz, plus four soft cues.
Standard library only. Reverb wraps around the loop boundary, avoiding a seam.
"""
import math, wave, struct, random
from pathlib import Path
RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets'
def write(name, samples):
    peak = max(1, max(abs(v) for v in samples) / .82)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v / peak)) * 32767)) for v in samples))
def note(buf, start, duration, midi, volume, airy=False):
    freq = 440 * 2 ** ((midi - 69) / 12)
    for j in range(int(duration * RATE)):
        t = j / RATE
        envelope = min(1, t / (.6 if airy else .025)) * math.exp(-t / (2.2 if airy else .8)) * min(1, (duration-t)/.25)
        tone = math.sin(2*math.pi*freq*t) + .22*math.sin(2*math.pi*freq*2*t) + .07*math.sin(2*math.pi*freq*3*t)
        buf[(int(start*RATE)+j) % len(buf)] += tone * envelope * volume
buf = [0.] * (RATE * 32)
chords = [(48,55,62,64), (45,52,59,60), (41,48,55,57), (43,50,57,62)]
melody = [76, 79, 74, 71, 72, 76, 69, 67, 69, 72, 76, 74, 74, 71, 67, 74]
for bar, chord in enumerate(chords):
    for pitch in chord: note(buf, bar*8, 10, pitch, .055, True)
    for beat in range(4): note(buf, bar*8+beat*1.8+.5, 3, melody[bar*4+beat], .10)
dry = buf[:]
for delay, gain in [(.31,.19),(.73,.13),(1.17,.08)]:
    offset=int(delay*RATE)
    for i,v in enumerate(dry): buf[(i+offset)%len(buf)] += v*gain
write('quiet-orbit', buf)
for name, pitches, duration in [('glint',[81,88],.65),('discovery',[72,76,79,86],1.9),('land',[48,55],.45),('drift',[60,67,74],1.2)]:
    buf=[0.] * int(RATE*duration)
    for i,pitch in enumerate(pitches): note(buf,i*.12,duration-i*.12,pitch,.19)
    write(name,buf)
