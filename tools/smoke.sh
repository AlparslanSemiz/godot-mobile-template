#!/usr/bin/env bash
# Smoke test: boots the game headless, taps Play, plays 10 s with scripted
# taps (fixed seed), and fails on any error or warning in the output.
set -uo pipefail
GODOT="${GODOT:-godot}"
SEED="${SEED:-42}"
mkdir -p builds
log="builds/smoke.log"

"$GODOT" --headless --path . --fixed-fps 60 -- \
	--driver=res://tests/smoke/smoke_driver.gd --seed="$SEED" >"$log" 2>&1
code=$?
cat "$log"

# The driver's own logger catches script-side problems; this also catches
# engine messages printed before it starts or after it quits (e.g. leaks).
if grep -nE '\b(ERROR|WARNING)\b' "$log"; then
	echo "smoke: FAIL — errors or warnings in output (see above)"
	exit 1
fi
if [ "$code" -ne 0 ] || ! grep -q 'smoke: PASS' "$log"; then
	echo "smoke: FAIL — exit code $code"
	exit 1
fi
