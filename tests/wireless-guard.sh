#!/bin/sh
set -eu

PATCH_FILE="${1:-patches/openwrt/002-pz-l8-wireless-guard.patch}"

fail() {
	echo "wireless guard test failed: $*" >&2
	exit 1
}

test -f "$PATCH_FILE" || fail "missing patch: $PATCH_FILE"

grep -Fq 'cmcc,pz-l8' "$PATCH_FILE" ||
	fail "guard is not scoped to the PZ-L8 board"
grep -Fq "config.band == '5g'" "$PATCH_FILE" ||
	fail "160 MHz fallback is not scoped to 5 GHz"
grep -Fq 'files-ucode/lib/netifd/wireless/mac80211.sh' "$PATCH_FILE" ||
	fail "160 MHz fallback does not patch the ucode backend used by the firmware"
grep -Fq "config.htmode = 'HE80'" "$PATCH_FILE" ||
	fail "HE160 does not fall back to HE80"
grep -Fq "case 'sae-compat':" "$PATCH_FILE" ||
	fail "ucode does not parse sae-compat as transition mode"
grep -Fq 'sae-mixed*|sae-compat*' "$PATCH_FILE" ||
	fail "sae-compat is not parsed as WPA2/WPA3 transition mode"

echo "wireless guard patch checks passed"
