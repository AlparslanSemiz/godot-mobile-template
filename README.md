<h1 align="center">Godot Mobile Template</h1>
<p align="center">A starting point for mobile games in Godot 4.7: tuned input and frame pacing, headless tests, Android and iOS exports, and a playable demo game.</p>

<p align="center">
<a href="https://github.com/AlparslanSemiz/godot-mobile-template/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/AlparslanSemiz/godot-mobile-template/test.yml?style=flat&label=test" alt="test"></a>
<img src="https://img.shields.io/badge/Godot-4.7.2-555?style=flat" alt="Godot 4.7.2">
<img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-555?style=flat" alt="Android and iOS">
<a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-555?style=flat" alt="MIT license"></a>
</p>

<p align="center"><b><a href="https://github.com/new?template_name=godot-mobile-template&template_owner=AlparslanSemiz">Use this template</a></b> · <a href="#start-a-new-game-from-this-template">steps</a></p>

## Why

An empty Godot project leaves you to set up export presets, input latency, tests, ads and a rebrand workflow before the first game line. This template has those done, with a small *Hop* demo game (GDScript with static typing, portrait 1080x1920 by default) that plays out of the box.

What makes it different from an empty project:

- **Tuned for feel.** Frame pacing, input and physics settings chosen and measured on a 120 Hz phone. See [FEEL.md](FEEL.md).
- **Tested headless.** `make test` lints every script with zero warnings allowed and runs GUT unit tests; `make smoke` plays 10 seconds with scripted taps and fails on any error; `make capture` records that session to MP4. CI runs `make test` and `make smoke`; `make capture` runs locally.
- **One file to rebrand.** Name, package id, version, orientation, ads and IAP switches all live in `game.cfg`.
- **Ads and in-app purchases ready, but off.** AdMob (with UMP consent) and Google Play Billing are wired behind small services; while switched off, the SDKs are not even in the build.
- **Agent-friendly.** [CLAUDE.md](CLAUDE.md) gives AI coding agents (Claude Code, Codex, Gemini) the rules, layout and definition of done.

## Requirements

- Godot 4.7.2-stable editor + export templates (`godot` on `PATH`, or `make GODOT=/path/to/godot …`)
- JDK 17 and the Android SDK, set in Godot's editor settings (`export/android/java_sdk_path`, `export/android/android_sdk_path`)
- `adb`, `ffmpeg` (with libx264), `python3`

## Commands

| Command | What it does |
| --- | --- |
| `make test` | Checks that `game.cfg` was applied, lints all scripts (no errors **or warnings**), runs the GUT unit tests headless. |
| `make smoke` | Boots the game headless, taps Play, plays 10 s with scripted taps (`SEED=42`), fails on any logged error or warning. |
| `make capture` | Same session recorded with Godot's Movie Maker: 1080x1920 PNG frames + `capture.mp4` in `builds/captures/<time>-seed<N>/`. |
| `make apk` | Debug APK (arm64) → `builds/android/game-debug.apk`. |
| `make install` | `adb install -r` the debug APK on the connected phone. |
| `make aab` | Signed release bundle → `builds/android/game-release.aab` (needs the keystore variables, see below). |
| `make ios` | Xcode project → `builds/ios/`. Building the `.ipa` needs a Mac. |
| `make config` | Copies `game.cfg` into `project.godot` and `export_presets.cfg` (every export target runs it). |
| `make lint` | Only the lint step of `make test`. |

## Start a new game from this template

1. Click **Use this template → Create a new repository** on GitHub (or `gh repo create <name> --template AlparslanSemiz/godot-mobile-template --clone`).
2. Edit `game.cfg`: `name`, `package` (reverse domain, never change it after the first store upload), `version_code`/`version_name`, `orientation`.
3. Replace `games/hop/` with your game, or add `games/<yours>/` and point `game.cfg → [game] scene` at it. Its root node needs `start(rng_seed: int)` and `signal finished(score: int)`; use the seed for every random choice.
4. Update `tests/smoke/smoke_driver.gd`'s autopilot for the new game's input (it uses `Hop.debug_state()` today).
5. `make config && make test && make smoke && make capture`, then look at the frames.
6. Replace `icon.svg`.

## Layout

```
game.cfg              per-game values (the only file you edit to rebrand)
project.godot         engine settings (see FEEL.md); name/size/orientation come from game.cfg
export_presets.cfg    Android (debug APK), Android Release (AAB), iOS. No secrets.
autoload/             SaveService, SettingsService, AudioService, AnalyticsService,
                      AdService, PurchaseService, SceneRouter
services/             backends behind the services (the defaults do nothing)
core/                 shared helpers: GameConfig, SafeArea, TapButton, Tones
scenes/               boot → menu (+ settings) → game shell → game over
games/hop/            the demo game
ui/theme.tres         shared UI theme
tests/unit/           GUT tests (test_*.gd)
tests/smoke/          scripted session used by `make smoke` and `make capture`
tools/                apply_config.gd, lint.py, smoke.sh, capture.sh
addons/gut/           GUT 9.7.1 (test-only, excluded from exports)
```

Game code only talks to the autoloads, never to an SDK or plugin directly. An SDK is wired in by writing a backend (extend `AdBackend` / `PurchaseBackend` / `AnalyticsBackend`) and passing it to the service's `set_backend()`.

## Unit test framework: GUT

GUT 9.7.1 was chosen over gdUnit4 6.2.2 because:

- GUT publishes a release specifically for this engine line (`godot_4_7` branch, compatibility table: "GUT 9.7.1: 4.7.x"). gdUnit4's table lists 4.5 through 4.7.1, not 4.7.2.
- It is pure GDScript in one folder with a stable headless CLI (`godot --headless -s addons/gut/gut_cmdln.gd`, exit code 1 on failure, JUnit XML output). gdUnit4 is larger and includes C# and editor tooling we don't need.
- It can assert on `push_warning`/`push_error` and fails a test on unexpected engine errors by default, which matches the "no warnings" rule.

Config: `.gutconfig.json`. Results: `builds/test-results.xml`.

## Display

- Base size 1080x1920 (portrait) or 1920x1080 (landscape), set from `game.cfg`. Stretch mode `canvas_items` with aspect `expand`: the UI keeps its size and the playfield grows to fill any screen shape, with no black bars.
- `SafeArea` (a `MarginContainer`) keeps HUD and menus out of notches and system bars using `DisplayServer.get_display_safe_area()`. To test it on desktop: `godot --path . -- --fake-safe-area=120,80`.

## Ads and in-app purchases

Both are **off by default** (`game.cfg`: `[ads] enabled=false`, `[iap] enabled=false`). Off means the plugin is not in the build at all: no SDK, no `AD_ID`/`BILLING` permission, no iOS frameworks, and the store/ad buttons are hidden. Set `enabled=true` and run `make config` to turn one on (ads also change the Play Data safety form and privacy policy).

- **AdMob:** Poing Studios plugin 5.1.0 in `addons/admob`. Review, hashes and local patch: `docs/plugin-review.md`, `patches/`.
- **Google Play Billing:** Godot's official plugin 3.3.0 in `addons/GodotGooglePlayBilling` (Android only).
- Game code calls only `AdService` (`show_interstitial()`, `show_rewarded()`, `ads_removed()`, privacy options) and `PurchaseService` (`buy_remove_ads()`, `restore_purchases()`).
- The real backends (`services/admob_ad_backend.gd`, `services/play_billing_backend.gd`) load automatically when the native plugin is present, so desktop runs and tests use the no-op backends.
- **Startup order:** UMP consent update → consent form if required → Mobile Ads init → preload one interstitial and one rewarded ad. Ads are requested only while consent is OBTAINED or NOT_REQUIRED.
- **Billing:** connects on start, queries product details and owned purchases, acknowledges one-time purchases, and grants or revokes "remove ads" from the store's answer.
- **Ad ids live in `game.cfg [ads]`.** They are Google's official test ids until you release. Debug builds show the consent form as if the phone were in the EEA (`debug_consent_eea`, `test_device_hashed_ids`).
- **Debug builds only:** Settings has "Debug: test interstitial / test rewarded" buttons.
- `make ios` runs `tools/ios_post_export.gd` after the export, so the AdMob Swift package gets linked in a command-line export.
- A full purchase test needs a Play Console internal testing build.

## Release signing (Android)

The upload keystore stays outside the repo.

1. Create it once (it asks for a password and your name):
   ```
   mkdir -p ~/keys && keytool -genkeypair -v -keystore ~/keys/game-upload.jks -alias upload \
     -keyalg RSA -keysize 2048 -validity 10000 -storetype PKCS12
   ```
2. Save the password in your password manager. Back up `~/keys/game-upload.jks` somewhere outside this machine. Losing it means asking Google to reset the upload key.
3. To build a release bundle, in your own terminal:
   ```
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keys/game-upload.jks
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload
   read -rs GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD && export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
   make aab
   ```

Nothing signing-related is ever written to the repo. `export_credentials.cfg` (Godot's own store for these, inside `.godot/`), `*.jks` and `*.keystore` are git-ignored.

## Status

Version 1.0.0. CI runs `make test` and `make smoke` on every push. The Android and iOS exports are built locally, not in CI. A Play Store release needs your own keystore and, if you turn ads or purchases on, your own ids.

## License

MIT for the template's own code. Bundled third-party addons keep their own licenses: GUT (MIT), Poing Studios AdMob plugin (MIT), GodotGooglePlayBilling (MIT). See each folder in `addons/`.
