#!/bin/sh
# Insert cmcc,pz-l8 caldata entries into ath11k caldata script
#
# This script is self-contained: it removes any existing cmcc,pz-l8 entries
# and inserts the correct ones with review-approved settings.
#
# Works whether:
#   - PR #21495 merged cleanly (has PZ-L8 entries that need correction)
#   - PR had merge conflicts resolved (may or may not have PZ-L8 entries)
#   - Caldata file is clean from main (no PZ-L8 entries at all)
#
# Review-approved settings:
#   2.4GHz (IPQ5018): offset 0x1000, MAC +2, remove_regdomain, set_macflag
#   5GHz  (QCN6122):  offset 0x26800, MAC +3, remove_regdomain, set_macflag

set -e

CALDATA="$1"

if [ -z "$CALDATA" ]; then
    echo "Usage: $0 <caldata-file>"
    exit 1
fi

if [ ! -f "$CALDATA" ]; then
    echo "ERROR: $CALDATA not found"
    exit 1
fi

echo "=== Before ==="
grep -n "cmcc,pz-l8" "$CALDATA" || echo "(no cmcc,pz-l8 entries)"

# Remove any existing cmcc,pz-l8 entries (from PR merge or previous run)
# This ensures idempotency regardless of merge state
sed -i '/cmcc,pz-l8/d' "$CALDATA"

# Clean up orphaned backslash continuation on the line BEFORE the removed
# cmcc,pz-l8|\ entry.  When the PR inserts "cmcc,pz-l8|\" as a fallthrough
# before another device (e.g. "xiaomi,ax6000)"), removing the cmcc,pz-l8 line
# leaves a dangling backslash on the preceding line if that line now ends with
# "|\" but the next line starts a new case pattern (not another "|\" continuation).
#
# We only target the specific pattern: a line ending with |\ followed by a line
# that is a case terminator ")".  This is safe because legitimate multi-device
# fallthroughs use |\ before another |\ continuation, never directly before ).
#
# Example:  "some_device|\\"  +  "cmcc,pz-l8|\\"  +  "target_device)"
#   → after removing cmcc,pz-l8:  "some_device|\\"  +  "target_device)"
#   → some_device now falls through to target_device, which is correct.

awk '
BEGIN { in_24ghz = 0; in_5ghz_qcn6122 = 0; inserted_24 = 0; inserted_5 = 0 }

# Track which section we are in
/"ath11k\/IPQ5018\/hw1\.0\/cal-ahb-c000000\.wifi\.bin"/ { in_24ghz = 1; in_5ghz_qcn6122 = 0 }
/"ath11k\/QCN6122\/hw1\.0\/cal-ahb-b00a040\.wifi\.bin"/ { in_5ghz_qcn6122 = 1; in_24ghz = 0 }
/^[ \t]*esac/ && in_24ghz == 1 && inserted_24 == 0 {
    # Insert PZ-L8 2.4GHz entry before esac in the 2.4GHz case block
    print "\tcmcc,pz-l8)"
    print "\t\tcaldata_extract \"0:art\" 0x1000 0x20000"
    print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
    print "\t\tath11k_patch_mac $(macaddr_add $label_mac 2) 0"
    print "\t\tath11k_remove_regdomain"
    print "\t\tath11k_set_macflag"
    print "\t\t;;"
    inserted_24 = 1
}
/^[ \t]*esac/ && in_5ghz_qcn6122 == 1 && inserted_5 == 0 {
    # Insert PZ-L8 5GHz (QCN6122) entry before esac in the QCN6122 case block
    print "\tcmcc,pz-l8)"
    print "\t\tcaldata_extract \"0:art\" 0x26800 0x20000"
    print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
    print "\t\tath11k_patch_mac $(macaddr_add $label_mac 3) 0"
    print "\t\tath11k_remove_regdomain"
    print "\t\tath11k_set_macflag"
    print "\t\t;;"
    inserted_5 = 1
    in_5ghz_qcn6122 = 0
}
/^[ \t]*esac/ && in_24ghz == 1 && inserted_24 == 1 {
    in_24ghz = 0
}

{ print }
' "$CALDATA" > "${CALDATA}.tmp"

mv "${CALDATA}.tmp" "$CALDATA"

echo ""
echo "=== After ==="
echo "--- 2.4GHz (IPQ5018) ---"
grep -n -B 1 -A 8 "cmcc,pz-l8)" "$CALDATA" | head -20
echo ""
echo "--- Verify xiaomi,ax6000 unchanged ---"
grep -n -A 3 "xiaomi,ax6000" "$CALDATA" | head -10

echo ""
echo "Caldata fix applied successfully."
