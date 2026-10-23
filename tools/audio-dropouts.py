import wave, struct, math, sys, statistics
path, t0 = sys.argv[1], float(sys.argv[2])            # recording file, offset of its start vs. phase clock (s)
phases = [(float(a), float(b), name) for a, b, name in (x.split(":") for x in sys.argv[3:])]   # start:end:name on the recording clock
w = wave.open(path); n = w.getnframes(); sr = w.getframerate(); d = struct.unpack("<%dh" % n, w.readframes(n))
win = sr // 100                                        # 10 ms
rms = [math.sqrt(sum(x * x for x in d[i:i + win]) / win) for i in range(0, n - win, win)]
ref = [statistics.median(rms[max(0, i - 30):i + 30]) for i in range(len(rms))]   # local level over +-300 ms
events = []; i = 0
while i < len(rms):
    if ref[i] > 400 and rms[i] < 0.12 * ref[i]:
        j = i
        while j < len(rms) and rms[j] < 0.12 * ref[j] and ref[j] > 400: j += 1
        events.append((i / 100.0, (j - i) * 10)); i = j
    else: i += 1
print(f"recording {n/sr:.0f} s, windows {len(rms)}, median level {statistics.median(rms):.0f}")
for a, b, name in phases:
    ev = [(t, ms) for t, ms in events if a <= t < b and ms >= 20]
    print(f"{name}: {b-a:.0f} s, dropouts >=20 ms: {len(ev)}", [f"{t:.1f}s/{ms}ms" for t, ms in ev][:12])
