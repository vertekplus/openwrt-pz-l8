#!/bin/sh
# Enhance or add cmcc,pz-l8 caldata entries in ath11k caldata script
#
# This script handles two scenarios:
#   - PR #21495 applied successfully (caldata has cmcc,pz-l8 entries)
#     → REPLACE: replace basic entries with full entries
#   - PR #21495 failed to apply (caldata has no cmcc,pz-l8 entries)
#     → INSERT: add new case blocks before esac in each section
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

if grep -q 'cmcc,pz-l8)' "$CALDATA"; then
    echo "=== Replacing existing cmcc,pz-l8 caldata entries ==="
    MODE="replace"
elif grep -q 'ath11k/IPQ5018/hw1.0/cal-ahb-c000000.wifi.bin' "$CALDATA"; then
    echo "=== No cmcc,pz-l8 entries found, will insert new entries ==="
    MODE="insert"
else
    echo "ERROR: $CALDATA does not contain ath11k/IPQ5018 caldata section."
    echo "Cannot add cmcc,pz-l8 entries."
    exit 1
fi

if [ "$MODE" = "replace" ]; then
    # Replace PR's basic cmcc,pz-l8 case blocks with our full entries.
    # For each section, pass through lines until we see "cmcc,pz-l8)", then
    # skip the original body until ";;", and emit our full entry instead.
    # Track sections by the caldata file path strings.
    # PR #21495 adds cmcc,pz-l8 in two different forms:
    #   - 2.4GHz section: "cmcc,pz-l8|\" as the FIRST line of a shared case
    #     block (sharing caldata_extract with xiaomi,ax6000/redmi-ax5400).
    #     This case has NO MAC patch — needs to be split out into its own
    #     block with full MAC patch.
    #   - 5GHz section: "cmcc,pz-l8)" as a standalone case block (also
    #     without MAC patch). Needs content replacement.
    #
    # The original awk regex only matched lines ending with ")" and missed
    # the 2.4GHz "cmcc,pz-l8|\" form, leaving 2.4GHz without a MAC patch
    # and causing ath11k to use a random MAC on every boot.
    awk '
    /"ath11k\/IPQ5018\/hw1\.0\/cal-ahb-c000000\.wifi\.bin"/ { in_24ghz = 1; in_5ghz = 0 }
    /"ath11k\/QCN6122\/hw1\.0\/cal-ahb-b00a040\.wifi\.bin"/ { in_5ghz = 1; in_24ghz = 0 }

    # Handle 2.4GHz shared case: "cmcc,pz-l8|\" as first line of shared block
    # Drop this line and emit a standalone cmcc,pz-l8 block BEFORE the
    # remaining shared case (xiaomi,ax6000|redmi-ax5400).
    in_24ghz && /^[ \t]*cmcc,pz-l8\|\\$/ && !done_24_shared {
        print "\tcmcc,pz-l8)"
        print "\t\tcaldata_extract \"0:art\" 0x1000 0x20000"
        print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
        print "\t\tath11k_patch_mac $(macaddr_add $label_mac 2) 0"
        print "\t\tath11k_remove_regdomain"
        print "\t\tath11k_set_macflag"
        print "\t\t;;"
        done_24_shared = 1
        next
    }

    # Handle standalone case block: "cmcc,pz-l8)" (used in 5GHz, and in 2.4GHz
    # if PR author had used standalone form)
    /^[ \t]*cmcc,pz-l8\)/ {
        in_block = 1
        print
        next
    }
    in_block && /^[ \t]*;;/ {
        # End of the cmcc,pz-l8 case block — emit our full entry
        if (in_24ghz) {
            print "\t\tcaldata_extract \"0:art\" 0x1000 0x20000"
            print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
            print "\t\tath11k_patch_mac $(macaddr_add $label_mac 2) 0"
            print "\t\tath11k_remove_regdomain"
            print "\t\tath11k_set_macflag"
        } else if (in_5ghz) {
            print "\t\tcaldata_extract \"0:art\" 0x26800 0x20000"
            print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
            print "\t\tath11k_patch_mac $(macaddr_add $label_mac 3) 0"
            print "\t\tath11k_remove_regdomain"
            print "\t\tath11k_set_macflag"
        }
        print $0
        in_block = 0
        next
    }
    in_block { next }  # Skip the original body (caldata_extract line)
    { print }
    ' "$CALDATA" > "${CALDATA}.tmp"

    mv "${CALDATA}.tmp" "$CALDATA"

else
    # Insert new cmcc,pz-l8 case blocks into clean upstream caldata file.
    # Each caldata path has its own case/esac block. We insert before esac.
    awk '
    BEGIN { in_24ghz = 0; in_5ghz = 0; inserted_24 = 0; inserted_5 = 0 }

    /"ath11k\/IPQ5018\/hw1\.0\/cal-ahb-c000000\.wifi\.bin"/ { in_24ghz = 1; in_5ghz = 0 }
    /"ath11k\/QCN6122\/hw1\.0\/cal-ahb-b00a040\.wifi\.bin"/ { in_5ghz = 1; in_24ghz = 0 }

    /^[ \t]*esac/ && in_24ghz == 1 && inserted_24 == 0 {
        print "\tcmcc,pz-l8)"
        print "\t\tcaldata_extract \"0:art\" 0x1000 0x20000"
        print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
        print "\t\tath11k_patch_mac $(macaddr_add $label_mac 2) 0"
        print "\t\tath11k_remove_regdomain"
        print "\t\tath11k_set_macflag"
        print "\t\t;;"
        inserted_24 = 1
    }

    /^[ \t]*esac/ && in_5ghz == 1 && inserted_5 == 0 {
        print "\tcmcc,pz-l8)"
        print "\t\tcaldata_extract \"0:art\" 0x26800 0x20000"
        print "\t\tlabel_mac=$(mtd_get_mac_binary 0:art 0)"
        print "\t\tath11k_patch_mac $(macaddr_add $label_mac 3) 0"
        print "\t\tath11k_remove_regdomain"
        print "\t\tath11k_set_macflag"
        print "\t\t;;"
        inserted_5 = 1
        in_5ghz = 0
    }

    /^[ \t]*esac/ && in_24ghz == 1 && inserted_24 == 1 {
        in_24ghz = 0
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
echo "Caldata entries ${MODE}d successfully."
