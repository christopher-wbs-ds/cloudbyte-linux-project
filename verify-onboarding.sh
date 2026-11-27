#!/bin/bash
# verify-onboarding.sh: CloudByte Section 3 self-check

# Adjust these two lines if your layout differs.
# Vagrant default:
# SCRIPT=/vagrant/scripts/onboard-user.sh
# CSV=/vagrant/data/new-hires.csv
# Lima users: comment the two lines above and uncomment these.
SCRIPT=/host/scripts/onboard-user.sh
CSV=/host/data/new-hires.csv

PASS=0
FAIL=0

check() {
    if eval "$1" > /dev/null 2>&1; then
        echo "✅ PASS: $2"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL: $2"
        FAIL=$((FAIL+1))
    fi
}

echo "=== CloudByte Section 3 check ==="

# --- Static checks against the script file -------------------------------
check "test -f \"$SCRIPT\"" "$SCRIPT exists"
check "head -n 20 \"$SCRIPT\" | grep -q 'set -eo pipefail'" \
      "Script enables strict mode (set -eo pipefail)"
check "grep -Eq '^create_user *\\(\\)' \"$SCRIPT\"" \
      "Script defines create_user function"
check "[ \"\$(grep -c '^# Usage:' \"$SCRIPT\")\" -ge 3 ]" \
      "Script header carries at least three # Usage: lines"

# --- Static checks against the CSV ---------------------------------------
check "test -f \"$CSV\"" "$CSV exists"
check "[ \"\$(wc -l < \"$CSV\")\" -ge 2 ]" \
      "CSV has a header row plus at least one data row"

# --- Behaviour: non-root invocation refuses politely ---------------------
NONROOT_OUT=$(bash "$SCRIPT" --help 2>&1)
NONROOT_RC=$?
check "[ \"$NONROOT_RC\" -ne 0 ] && echo \"$NONROOT_OUT\" | grep -qi 'root'" \
      "Non-root invocation prints an error and exits non-zero"

# --- Behaviour: --help prints Usage and exits 0 --------------------------
HELP_OUT=$(sudo bash "$SCRIPT" --help 2>&1)
HELP_RC=$?
check "[ \"$HELP_RC\" -eq 0 ] && echo \"$HELP_OUT\" | grep -qi 'usage'" \
      "--help exits 0 and prints a Usage line"

# --- Behaviour: --dry-run creates no users -------------------------------
DRY_USERS="verify_dry_a verify_dry_b"
for u in $DRY_USERS; do sudo userdel -r "$u" > /dev/null 2>&1; done
DRY_CSV=$(mktemp /tmp/verify-dry-XXXXXX.csv)
cat > "$DRY_CSV" <<'EOF'
username,group,fullname
verify_dry_a,engineering,Dry Run A
verify_dry_b,marketing,Dry Run B
EOF
sudo bash "$SCRIPT" --csv "$DRY_CSV" --dry-run > /dev/null 2>&1
check "! getent passwd verify_dry_a >/dev/null && ! getent passwd verify_dry_b >/dev/null" \
      "--dry-run does not create any users"
for u in $DRY_USERS; do sudo userdel -r "$u" > /dev/null 2>&1; done
rm -f "$DRY_CSV"

# --- Behaviour: fresh CSV run + idempotency ------------------------------
RUN_USERS="verify_run_a verify_run_b verify_run_c"
for u in $RUN_USERS; do sudo userdel -r "$u" > /dev/null 2>&1; done
RUN_CSV=$(mktemp /tmp/verify-run-XXXXXX.csv)
cat > "$RUN_CSV" <<'EOF'
username,group,fullname
verify_run_a,engineering,Verify Run A
verify_run_b,marketing,Verify Run B
verify_run_c,operations,Verify Run C
EOF
sudo bash "$SCRIPT" --csv "$RUN_CSV" > /dev/null 2>&1
check "getent passwd verify_run_a >/dev/null && getent passwd verify_run_b >/dev/null && getent passwd verify_run_c >/dev/null" \
      "CSV run creates verify_run_a, verify_run_b, verify_run_c"
check "id -nG verify_run_a 2>/dev/null | grep -qw engineering" \
      "verify_run_a is a member of engineering"
check "id -nG verify_run_b 2>/dev/null | grep -qw marketing" \
      "verify_run_b is a member of marketing"
check "id -nG verify_run_c 2>/dev/null | grep -qw operations" \
      "verify_run_c is a member of operations"

RERUN_OUT=$(sudo bash "$SCRIPT" --csv "$RUN_CSV" 2>&1)
RERUN_RC=$?
check "[ \"$RERUN_RC\" -eq 0 ] && [ \"\$(echo \"$RERUN_OUT\" | grep -c '^Skip:')\" -ge 3 ]" \
      "Second CSV run is idempotent (three Skip lines, exit 0)"
for u in $RUN_USERS; do sudo userdel -r "$u" > /dev/null 2>&1; done
rm -f "$RUN_CSV"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]