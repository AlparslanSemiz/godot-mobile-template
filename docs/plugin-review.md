# Plugin code review (money test)

Date: 2026-10-24 · Reviewer: Claude Code · Status: **approved**, merged on 2026-10-24.

## What was downloaded

Only the pinned release assets from the official repos. Each SHA-256 matches the `digest` GitHub publishes for that asset.

| Archive | Source | SHA-256 |
| --- | --- | --- |
| `poing-godot-admob-v5.1.0.zip` | github.com/poingstudios/godot-admob-plugin, release v5.1.0 | `8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f` |
| `android-template-v4.7.2.zip` | same release | `f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee` |
| `ios-template-v4.7.2.zip` | same release | `6e7f1c807761f9c0ad45d335ac4c74acd4bba7a31f9e1c7cd16a5220010cce71` |
| `godot-google-play-billing.zip` | github.com/godot-sdk-integrations/godot-google-play-billing, release 3.3.0 | `20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568` |

## What was read

Every GDScript file that would land in `addons/`:

- AdMob addon: 119 `.gd` files (11,947 lines): editor plugin, exporters, installers, services, mocks, runtime API, sample. Also the GDScript embedded in two sample `.tscn` files.
- AdMob platform packages: 19 Android + 19 iOS `.gd` export descriptors.
- Billing: 2 `.gd` files (195 lines).

Not GDScript, so not reviewed line by line: the prebuilt `.aar` (Android) and `.a`/xcframework (iOS) binaries. These run on the phone, not on the laptop. Also not reviewed: 91 C# files, which a non-.NET Godot never loads (the plugin hides that folder with a `.gdignore`).

## Findings that match your stop criteria

### 1. Shell commands: `OS.execute` (AdMob)

`internal/services/network/binary_installer.gd` runs every time the editor plugin loads (`admob.gd → _enter_tree`).

**Only in headless mode** (which is how I run every Godot command), and only if `addons/admob/android/bin/package.gd` or `addons/admob/ios/bin/package.gd` is missing, it runs:

```
which curl            (or: which wget)
curl -L -o <project>/addons/admob/downloads/<platform>/<platform>-template-v4.7.2.zip \
  https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/<platform>-template-v4.7.2.zip
```

It then extracts the zip into `addons/admob/<platform>/bin/`. For Android it deletes that folder first. On Windows it would run PowerShell `Invoke-WebRequest` instead. The URL is fixed to the official release of the installed version.

### 2. Network requests: `HTTPRequest` (AdMob)

`internal/services/network/download_service.gd`, used by `internal/editor/editor_menu.gd`.

- **In the GUI editor only:** on editor start, if the same `package.gd` files are missing, it automatically downloads the same zips from the same URL into `addons/admob/downloads/`.
- It also downloads when you click *Project → Tools → AdMob Manager → Android/iOS → Download & Install*.

### 3. Opening URLs: `OS.shell_open` (AdMob)

These open the browser only when someone clicks them in the GUI editor:

- AdMob Manager menu items: GitHub, docs, Discord, Google group, Patreon, Ko-fi, PayPal, and the downloads folder (`file://…/addons/admob/downloads/`).
- The Patreon button in the sample scene.

Never in headless or CLI runs.

### 4. File writes

All of them stay inside the project.

**Editor plugin load:**
- `ProjectSettings.save()`: adds `admob/*` keys to `project.godot` and removes any unknown `admob/*` key.
- Creates `addons/admob/csharp/.gdignore`.

**Android export:**
- Appends an exclude block for the old `play-services-ads` artifact to `android/build/build.gradle`. This is Godot's Gradle template inside the project; it is git-ignored and regenerated.
- If `enable_r8_optimization` is on (default **off**), it also edits `build.gradle` and `proguard-rules.pro`.

**iOS export:** writes `admob_spm/Package.swift` and `Dummy.swift`, and patches `project.pbxproj` in the export folder (`builds/ios/`).

**Only when clicked or run:**
- *AI Copilot → Install AI Skills* copies `addons/admob/skills/` to `res://.skills/`.
- The sample scene writes `user://sample_admob_settings.cfg`.

Nothing reads or writes outside the project (or outside the export folder you choose).

### 5. Build-time downloads (not GDScript, normal for any SDK)

- `make apk`/`make aab`: Gradle downloads `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.4.0`, `androidx.constraintlayout:2.2.0` and `com.android.billingclient:billing-ktx:9.1.0` from Google Maven / Maven Central.
- iOS: when the Xcode project is built (on a Mac), Swift Package Manager fetches `GoogleMobileAds` 13.9.0 and `GoogleUserMessagingPlatform` 3.1.0 from github.com/googleads.
- Mediation adapters add more repos (for example Chartboost's jfrog), but they are all **off** by default and stay off.

## Clean

- **AdMob runtime API** (`gdscript/src/**`): only calls the native `PoingGodotAdMob*` singletons on the phone. On desktop editor builds it falls back to mock nodes that draw fake ads. No file, network or shell access.
- **Mocks** (`internal/mock/**`): UI only.
- **Billing plugin:** `export_plugin.gd` only returns the AAR path and the Maven dependency. `BillingClient.gd` only wraps the native `GodotGooglePlayBilling` singleton.

## Other notes

- The AdMob package ships `.gitignore` files that ignore `addons/admob/android/bin` and `addons/admob/ios/bin`. Our no-LFS decision means binaries are committed, so those two `.gitignore` files would have to go. Otherwise a fresh clone has no binaries, and finding 1 would kick in on the first headless run.
- Size added to the repo: addon ~5 MB, Android libs ~0.4 MB, iOS libs ~11.7 MB (all 17 mediation adapters included; 7.8 MB is the core `ads` library).

## Options

| Option | What I do | Effect |
| --- | --- | --- |
| **A (recommended)** | Install the pinned packages exactly as downloaded, including `package.gd`, so the download code never triggers. Remove the two nested `.gitignore` files so the binaries are committed. Add a `make` guard that fails before any Godot command if either `package.gd` is missing. | Plugin code unchanged and easy to update. The download paths exist but cannot trigger while the guard holds. |
| B | A, plus a two-line local patch: comment out `BinaryInstaller.install_missing_binaries_sync()` in `admob.gd` and the `check_dependencies()` calls in `editor_menu.gd`. Recorded in `addons/admob/LOCAL_PATCHES.md`. | The plugin can never shell out or auto-download, even if files go missing. The patch has to be re-applied on every plugin update. |
| C | Don't use Poing. Try `godot-sdk-integrations/godot-admob` v7.0 instead (I have not reviewed its code). | It has open bugs on exactly what we need: "not initializing on 4.7" and "can't set debug_geography". |

The Billing plugin has no findings and can be installed as is.
