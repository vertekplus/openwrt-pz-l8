#!/bin/sh
# Enhance or add cmcc,pz-l8 caldata entries in ath11k caldata script
#
# PR #21495 adds basic caldata_extract entries for cmcc,pz-l8.
# This script:
#   - If cmcc,pz-l8 entries already exist → replaces their body with full entries
#     (MAC address patching, regdomain removal, macflag setting)
#   - If no cmcc,pz-l8 entries exist → adds new case blocks in the appropriate
#     2.4GHz and 5GHz sections
#
# Usage: fix-caldata.sh <caldata-file>

CALDATA="$1"

if [ -z "$CALDATA" ]; then
    echo "Usage: $0 <caldata-file>"
    exit 1
fi

if [ ! -f "$CALDATA" ]; then
    echo "ERROR: $CALDATA not found"
    exit 1
fi

if grep -q 'cmcc,pz-l8)' "$CALDATA"; then
    echo "=== Replacing existing cmcc,pz-l8 caldata entries ==="
    MODE="replace"
elif grep -q 'ath11k/IPQ5018/hw1.0/cal-ahb-c000000.wifi.bin' "$CALDATA"; then
    echo "=== No cmcc,pz-l8 entries found, will add new entries ==="
    MODE="add"
else
    echo "ERROR: $CALDATA does not contain ath11k/IPQ5018 caldata section."
    echo "Cannot add cmcc,pz-l8 entries."
    exit 1
fi

if [ "$MODE" = "replace" ]; then
    # Replace existing cmcc,pz-l8 case blocks with our full entries.
    awk '
    /^[ \t]*cmcc,pz-l8\)/ { in_block=1; print; next }
    in_block && /^[ \t]*;;/ {
        if (in_24ghz) {
            print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
            print "\t\tath11k_patch_mac $(macaddr_add $label_mac 2) 0"
            print "\t\tath11k_remove_regdomain"
            print "\t\tath11k_set_macflag"
        } else if (in_5ghz_qcn6122) {
            print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
            print "\t\tath11k_patch_mac $(macaddr_add $label_mac 3) 0"
            print "\t\tath11k_remove_regdomain"
            print "\t\tath11k_set_macflag"
        }
        print $0
        in_block=0
        next
    }
    in_block { next }
    /"ath11k\/IPQ5018\/hw1\.0\/cal-ahb-c000000\.wifi\.bin"/ { in_24ghz = 1; in_5ghz_qcn6122 = 0 }
    /"ath11k\/QCN6122\/hw1\.0\/cal-ahb-b00a040\.wifi\.bin"/ { in_5ghz_qcn6122 = 1; in_24ghz = 0 }
    { print }
    ' "$CALDATA" > "${CALDATA}.tmp"

    mv "${CALDATA}.tmp" "$CALDATA"
else
    # Add new cmcc,pz-l8 case blocks.
    # Insert before the last ';;' before 'esac' in each section,
    # or after the last case entry in each section.
    #
    # Strategy: find the esac of each section's case block and insert
    # a new cmcc,pz-l8 block before it.

    # 2.4GHz entry (IPQ5018)
    ENTRY_24GHZ='
        cmcc,pz-l8)
                caldata_extract "0:art" 0x1000 0x20000
                label_mac=$(mtd_get_mac_binary 0:art 0)
                ath11k_patch_mac $(macaddr_add $label_mac 2) 0
                ath11k_remove_regdomain
                ath11k_set_macflag
                ;;'

    # 5GHz entry (QCN6122)
    ENTRY_5GHZ='
        cmcc,pz-l8)
                caldata_extract "0:art" 0x26800 0x20000
                label_mac=$(mtd_get_mac_binary 0:art 0)
                ath11k_patch_mac $(macaddr_add $label_mac 3) 0
                ath11k_remove_regdomain
                ath11k_set_macflag
                ;;'

    awk -v entry24="$ENTRY_24GHZ" -v entry5g="$ENTRY_5GHZ" '
    /"ath11k\/IPQ5018\/hw1\.0\/cal-ahb-c000000\.wifi\.bin"/ { in_24ghz = 1; in_5ghz_qcn6122 = 0; added_24 = 0 }
    /"ath11k\/QCN6122\/hw1\.0\/cal-ahb-b00a040\.wifi\.bin"/ { in_5ghz_qcn6122 = 1; in_24ghz = 0; added_5g = 0 }
    # Detect case/esac boundaries
    /^[ \t]*case[ \t]/ { in_case = 1 }
    /^[ \t]*esac/ {
        # Before closing esac, insert entry if not yet added in this section
        if (in_case && in_24ghz && !added_24) {
            print entry24
            added_24 = 1
        }
        if (in_case && in_5ghz_qcn6122 && !added_5g) {
            print entry5g
            added_5g = 1
        }
        in_case = 0
        print
        next
    }
    { print }
    ' "$CALDATA" > "${CALDATA}.tmp"

    mv "${CALDATA}.tmp" "$CALDATA"
fi

# Verify result has no syntax errors
if ! bash -n "$CALDATA"; then
    echo "ERROR: Generated caldata file has syntax errors!"
    exit 1
fi

echo "=== Result ==="
echo "--- 2.4GHz (IPQ5018) ---"
grep -n -B 1 -A 8 "cmcc,pz-l8)" "$CALDATA" | head -20
echo ""
echo "--- 5GHz (QCN6122) ---"
grep -n -B 1 -A 8 "cmcc,pz-l8)" "$CALDATA" | tail -12

echo ""
echo "Caldata entries enhanced successfully."
