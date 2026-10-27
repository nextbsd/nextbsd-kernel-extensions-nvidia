#!/bin/sh
# personalities-selftest.sh — prove gen-nvidia-personalities.sh against a
# synthetic supported-gpus.json on every PR, without building the driver.
#
# Moved unchanged from nextbsd-kernel-extensions-graphics' tests/personalities-selftest.sh
# with the NVIDIA tools (nextbsd/nextbsd#548).
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOOLS="$HERE/../tools"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

chmod +x "$TOOLS"/gen-nvidia-personalities.sh

# --- nvidia: supported-gpus.json with a Turing chip (no legacybranch, so the
#     current unified driver owns it) plus one 580.xx and one 470.xx legacy chip.
#     0x1e07 is uppercase in the fixture to prove case-normalisation. Asserts the
#     branch partition: default mode = Turing only; -b picks exactly one branch;
#     the three match sets are disjoint (the legacybranch split guarantees it). ---
cat > "$WORK/supported-gpus.json" <<'EOF'
{ "chips": [
	{ "devid": "0x1E07", "name": "NVIDIA GeForce RTX 2080 Ti (TU102)", "features": ["drmkms"] },
	{ "devid": "0x2182", "name": "NVIDIA GeForce GTX 1660 Ti (TU116)", "features": ["drmkms"] },
	{ "devid": "0x13C2", "name": "NVIDIA GeForce GTX 970 (Maxwell)", "legacybranch": "580.xx" },
	{ "devid": "0x0FC6", "name": "NVIDIA GeForce GTX 650 (Kepler)", "legacybranch": "470.xx" },
	{ "devid": "*",      "name": "wildcard row that must be skipped" }
] }
EOF
NV=$("$TOOLS/gen-nvidia-personalities.sh" "$WORK/supported-gpus.json" org.nextbsd.driver.NVIDIAGraphics595 NVIDIAGraphics595)
printf '%s\n' "$NV"
printf '%s\n' "$NV" | grep -q '0x1e0710de' || fail "nvidia: 0x1E07 (Turing) missing or not lowercased"
printf '%s\n' "$NV" | grep -q '0x218210de' || fail "nvidia: 0x2182 (Turing) missing"
if printf '%s\n' "$NV" | grep -q '0x13c210de'; then
	fail "nvidia: 0x13C2 (580 legacy) leaked into the unified-driver kext"
fi
if printf '%s\n' "$NV" | grep -q '0x0fc610de'; then
	fail "nvidia: 0x0FC6 (470 legacy) leaked into the unified-driver kext"
fi
if printf '%s\n' "$NV" | grep -q '0x2a2a10de'; then
	fail "nvidia: wildcard '*' devid was not skipped"
fi

# -b 470.xx must select ONLY the Kepler chip.
NV470=$("$TOOLS/gen-nvidia-personalities.sh" -b 470.xx "$WORK/supported-gpus.json" org.nextbsd.driver.NVIDIAGraphics470 NVIDIAGraphics470)
printf '%s\n' "$NV470" | grep -q '0x0fc610de' || fail "nvidia -b 470.xx: 0x0FC6 missing"
if printf '%s\n' "$NV470" | grep -q '0x1e0710de'; then
	fail "nvidia -b 470.xx: Turing id 0x1E07 wrongly included"
fi

# cross-check: the unified (595) and 470 match sets must be DISJOINT.
printf '%s\n' "$NV"    | grep -oE '0x[0-9a-f]{8}' | sort -u > "$WORK/nv595-match.txt"
printf '%s\n' "$NV470" | grep -oE '0x[0-9a-f]{8}' | sort -u > "$WORK/nv470-match.txt"
NVOVERLAP=$(comm -12 "$WORK/nv595-match.txt" "$WORK/nv470-match.txt")
[ -z "$NVOVERLAP" ] || fail "NVIDIAGraphics595 and NVIDIAGraphics470 share ids: $NVOVERLAP"
echo "de-overlap OK: NVIDIA 595/470 match sets disjoint (legacybranch partition)"

# well-formedness of the nvidia fragment (same plist check as above).
if command -v python3 >/dev/null 2>&1; then
	{
		printf '%s' '<?xml version="1.0" encoding="UTF-8"?>'
		printf '%s' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
		printf '%s' '<plist version="1.0"><dict>'
		printf '%s' "$NV"
		printf '%s' '</dict></plist>'
	} > "$WORK/wrap.plist"
	python3 - "$WORK/wrap.plist" NVIDIAGraphics595 <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], 'rb'))
cls = sys.argv[2]
p = d['IOKitPersonalities'][cls]
assert p['IOProviderClass'] == 'IOPCIDevice', p
assert p['IOClass'] == cls, p
ids = p['IOPCIPrimaryMatch'].split()
assert ids and all(x.startswith('0x') and len(x) == 10 for x in ids), ids[:3]
print(f"{cls}: plist OK, {len(ids)} device ids")
PY
fi

echo "ALL NVIDIA PERSONALITY SELF-TESTS PASSED"
