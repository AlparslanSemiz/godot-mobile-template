#!/usr/bin/env bash
# Records the smoke session with Godot's Movie Maker at 1080x1920/60 fps and
# turns it into an MP4. Output: builds/captures/<time>-seed<N>/{frames/,capture.mp4}
set -euo pipefail
GODOT="${GODOT:-godot}"
SEED="${SEED:-42}"
out="builds/captures/$(date +%Y%m%d-%H%M%S)-seed$SEED"
mkdir -p "$out/frames"

# Render at full store resolution without touching project.godot.
# override.cfg is git-ignored and removed even if the run fails. Refuse to run
# if one already exists, so a developer's own override is never deleted.
if [ -e override.cfg ]; then
	echo "capture: override.cfg already exists; move it away first." >&2
	exit 1
fi
trap 'rm -f override.cfg' EXIT
cat > override.cfg <<'CFG'
[display]

window/size/window_width_override=1080
window/size/window_height_override=1920
CFG

# --disable-vsync: otherwise a window hidden behind other windows is throttled
# to a few fps by the compositor. Movie Maker fixes game time to 60 fps anyway.
"$GODOT" --path . --disable-vsync --fixed-fps 60 --write-movie "$out/frames/frame.png" -- \
	--driver=res://tests/smoke/smoke_driver.gd --seed="$SEED" 2>&1 | tee "$out/log.txt"

ffmpeg -loglevel error -y -framerate 60 -i "$out/frames/frame%08d.png" -i "$out/frames/frame.wav" \
	-c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium -movflags +faststart \
	-c:a aac -b:a 128k -shortest "$out/capture.mp4"

frames=$(ls "$out/frames" | grep -c '\.png$')
echo "capture: $frames frames + $out/capture.mp4"
