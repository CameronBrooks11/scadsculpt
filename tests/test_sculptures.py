"""Render each sculpture and check it's one solid, faces outward, sits on the bed and keeps its size.

usage: python3 tests/test_sculptures.py [OPENSCAD]

- Every sculpture renders with --hardwarnings as one solid, with a positive
  signed volume (its faces point outward), its lowest point on z = 0.
- Its bounding box matches the size below. The three older sculptures had these
  sizes before they were lifted onto the bed, so a change here is a change of
  shape, not just of position.
- flame_plumes refuses impossible input with its messages.
"""

import os
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SIZES = {
    "chiral_sonic_bloom.scad": (158.06, 145.61, 65.57),
    "crystal_helix_knot.scad": (101.38, 101.38, 80.21),
    "hyper_gargoyle.scad": (95.62, 97.78, 162.08),
    "flame_plumes.scad": (68.79, 59.80, 180.00),
}


def measure(path):
    data = open(path, "rb").read()
    (n,) = struct.unpack_from("<I", data, 80)
    tris = [struct.unpack_from("<9f", data, 84 + i * 50 + 12) for i in range(n)]
    parent = {}

    def find(v):
        while parent[v] != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    volume = 0
    for t in tris:
        a, b, c = t[0:3], t[3:6], t[6:9]
        volume += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0])
                   + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6
        for p in (a, b, c):
            parent.setdefault(p, p)
        root = find(a)
        for p in (b, c):
            parent[find(p)] = root
    pts = list(parent)
    lo = [min(p[i] for p in pts) for i in range(3)]
    size = [max(p[i] for p in pts) - lo[i] for i in range(3)]
    return len({find(v) for v in parent}), lo, size, volume


results = []


def check(label, ok, got):
    results.append(bool(ok))
    print(f"{'ok  ' if ok else 'FAIL'} {label}: {got}")


def main():
    openscad = sys.argv[1] if len(sys.argv) > 1 else "openscad"
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "out.stl")
        for name, want in SIZES.items():
            r = subprocess.run([openscad, "--hardwarnings", "--export-format", "binstl", "-o", out,
                                os.path.join(ROOT, name)], capture_output=True, text=True)
            bad = [l for l in r.stderr.splitlines() if "WARNING" in l or "ERROR" in l]
            if r.returncode != 0 or bad:
                check(name, False, bad[:1] or f"exit {r.returncode}")
                continue
            solids, lo, size, volume = measure(out)
            ok = solids == 1 and volume > 0 and abs(lo[2]) < 0.01 \
                and all(abs(a - b) <= 0.01 for a, b in zip(size, want))
            check(name, ok, f"{solids} solid(s), volume {volume:.0f} mm3, {' x '.join(f'{s:.2f}' for s in size)} mm "
                  f"from z = {lo[2]:.2f}; want 1, positive, {' x '.join(f'{s:.2f}' for s in want)} from 0")

        for label, params, message in [
            ("flame refuses a lobe depth of 1", ["-D", "lobe_depth=1"], "lobe_depth has to be"),
            ("flame refuses a single slice", ["-D", "slices_per_strand=1"], "at least 2 slices"),
        ]:
            r = subprocess.run([openscad, "--export-format", "binstl", "-o", out, *params,
                                os.path.join(ROOT, "flame_plumes.scad")], capture_output=True, text=True)
            errors = [l for l in r.stderr.splitlines() if "ERROR" in l]
            check(label, errors and message in errors[0], errors[0][:100] if errors else f"exit {r.returncode}")

    print(f"{sum(results)} of {len(results)} checks passed")
    sys.exit(0 if all(results) else 1)


main()
