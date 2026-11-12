# Build commands. Run `make help` for the list.
# Override the engine binary with `make GODOT=/path/to/godot <target>`.

GODOT ?= godot
SEED ?= 42
ADB ?= adb

APK := builds/android/game-debug.apk
AAB := builds/android/game-release.aab
IOS := builds/ios/game.xcodeproj
G := $(GODOT) --headless --path .

.PHONY: help plugin-check import config check-config lint test smoke capture apk install aab ios clean

help:
	@echo "make test      config check + lint (no warnings) + GUT unit tests"
	@echo "make smoke     headless 10 s scripted session, fails on any error/warning"
	@echo "make capture   same session recorded to builds/captures/ (PNG frames + MP4)"
	@echo "make apk       debug APK (arm64)           -> $(APK)"
	@echo "make install   adb install the debug APK on the connected phone"
	@echo "make aab       signed release bundle       -> $(AAB) (needs keystore env vars)"
	@echo "make ios       Xcode project               -> $(IOS)"
	@echo "make config    copy game.cfg into project.godot and export_presets.cfg"
	@echo "make lint      GDScript errors and warnings via Godot's language server"
	@echo "make plugin-check  AdMob binaries present + local no-download patch applied"

# The AdMob plugin downloads its binaries (curl via OS.execute) when
# addons/admob/{android,ios}/bin/package.gd is missing, unless our local
# patch is applied. Every target that starts Godot checks that, plus the
# SHA-256 of every plugin file (code and binaries, patched state included).
plugin-check:
	@if [ -d addons/admob ]; then \
		for f in addons/admob/android/bin/package.gd addons/admob/ios/bin/package.gd; do \
			test -f $$f || { echo "plugin-check: missing $$f (reinstall the pinned AdMob packages, see CLAUDE.md)"; exit 1; }; \
		done; \
		git apply --reverse --check patches/admob-no-autodownload.patch 2>/dev/null || \
			{ echo "plugin-check: patches/admob-no-autodownload.patch is not applied. Run: git apply patches/admob-no-autodownload.patch"; exit 1; }; \
		sha256sum -c --quiet patches/third_party.sha256 || \
			{ echo "plugin-check: plugin files differ from patches/third_party.sha256 (see CLAUDE.md, updating a plugin)"; exit 1; }; \
	fi

# Fresh clones have no .godot/ cache; class names and imports need it.
.godot/imported: | plugin-check
	$(G) --import >/dev/null 2>&1 || true
	@touch $@

import: plugin-check
	$(G) --import
	@touch .godot/imported

config: plugin-check .godot/imported
	$(G) --script res://tools/apply_config.gd

check-config: plugin-check .godot/imported
	$(G) --script res://tools/apply_config.gd -- --check

lint: plugin-check .godot/imported
	GODOT=$(GODOT) python3 tools/lint.py

test: check-config lint
	@mkdir -p builds
	$(G) -s addons/gut/gut_cmdln.gd

smoke: plugin-check .godot/imported
	GODOT=$(GODOT) SEED=$(SEED) tools/smoke.sh

capture: plugin-check .godot/imported
	GODOT=$(GODOT) SEED=$(SEED) tools/capture.sh

# --install-android-build-template only runs when android/ is missing.
ANDROID_TEMPLATE_FLAG = $(if $(wildcard android/build),,--install-android-build-template)

apk: config
	@mkdir -p builds/android
	$(G) $(ANDROID_TEMPLATE_FLAG) --export-debug "Android" $(APK)
	@ls -la $(APK)

install:
	@test -f $(APK) || (echo "No APK yet, run: make apk" && exit 1)
	$(ADB) install -r $(APK)

# Release signing comes only from environment variables (never from the repo):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER, _PASSWORD
aab: config
	@test -n "$$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" -a -n "$$GODOT_ANDROID_KEYSTORE_RELEASE_USER" \
		-a -n "$$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" || \
		(echo "Set GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD first (see README, Release signing)." && exit 1)
	@mkdir -p builds/android
	$(G) $(ANDROID_TEMPLATE_FLAG) --export-release "Android Release" $(AAB)
	@ls -la $(AAB)

ios: plugin-check config
	@mkdir -p builds/ios
	$(G) --export-release "iOS" $(IOS)
	@if [ -d builds/ios/admob_spm ]; then $(G) --script res://tools/ios_post_export.gd -- $(IOS); fi
	@ls -d builds/ios/*

clean:
	rm -rf builds .godot

