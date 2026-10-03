"""Original, quiet UI cues for the Citrus demo. No third-party recordings."""
import math
import struct
import sys
import wave

rate = 48000
duration = 28
samples = [0.0] * (rate * duration)
cue_times = [0.35, 3.90, 5.65, 7.25, 10.40, 11.60, 13.15, 14.70, 15.65,
             17.40, 18.40, 19.55, 20.65, 22.45, 24.40]
for cue_index, start in enumerate(cue_times):
    length = 0.18 if cue_index not in (0, 1, 4, 9, 14) else 0.34
    for n in range(int(length * rate)):
        t = n / rate
        envelope = min(1.0, t / 0.008) * math.exp(-t * 22.0)
        base = 760 if cue_index % 3 else 570
        value = 0.048 * envelope * (math.sin(2 * math.pi * base * t)
                                   + 0.34 * math.sin(2 * math.pi * base * 1.5 * t))
        index = int(start * rate) + n
        if index < len(samples):
            samples[index] += value
with wave.open(sys.argv[1], "wb") as output:
    output.setnchannels(2)
    output.setsampwidth(2)
    output.setframerate(rate)
    frames = bytearray()
    for value in samples:
        integer = int(max(-1, min(1, value)) * 32767)
        frames.extend(struct.pack("<hh", integer, integer))
    output.writeframes(frames)
print("Original light cues: 28 s, 48 kHz, stereo")
