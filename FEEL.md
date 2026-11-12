# Feel: instant and smooth

In an early side-by-side test, Unity felt "a bit smoother" and Godot felt "instant". Both ran at about 120 fps with 0 dropped frames, so frame rate was not the cause. This file lists every setting the template uses to get both, and why. All of them were checked against the Godot 4.7.2 class reference (`doc/classes/ProjectSettings.xml` at tag `4.7.2-stable`).

Note: Godot leaves out of `project.godot` any setting that equals its default. Settings marked *(default)* below are active even though you won't see them in the file.

## What probably made Unity look smoother

The first Godot prototype had three gaps:

1. **No frame pacing on Android.** Godot's frame pacing library (Swappy, the same Android Frame Pacing library Unity turns on by default as "Optimized Frame Pacing") is only wired into the Vulkan renderer (`drivers/vulkan` in the Godot source). the first prototype used the Compatibility (OpenGL) renderer, so it never had it. A steady 120 fps average can still deliver frames at uneven times; you feel that as a slight stutter even though the fps counter looks perfect.
2. **Movement tied to variable frame time.** The prototype moved everything in `_process(delta)`. Any uneven `delta` shows up directly as uneven motion.
3. **No easing or follow-through.** Everything snapped: no squash, no tilt, no transitions. That reads as "instant" but also as "stiff".

## Smooth

| Setting | Value | Why |
| --- | --- | --- |
| `rendering/renderer/rendering_method(.mobile)` | `mobile` | Vulkan renderer, which is what gives Android frame pacing (see above). |
| `rendering/rendering_device/fallback_to_opengl3` | `true` *(default)* | Phones without working Vulkan fall back to OpenGL automatically instead of failing to start. |
| `display/window/frame_pacing/android/enable_frame_pacing` | `true` *(default)* | Turns Swappy on. The docs call it "highly recommended". |
| `display/window/frame_pacing/android/swappy_mode` | `auto_fps_auto_pipeline` *(default)* | Swappy picks a frame rate it can hold and turns pipelining off when frames render fast, which also cuts latency. A simple 2D game renders far under budget, so it stays at the screen's full rate (120 Hz on the test phone, measured). `pipeline_forced_on` was tested and rejected: it let the phone drop to 60/90 Hz for ~40 % of the time (see "Measured" below). |
| `display/window/vsync/vsync_mode` | `Enabled` *(default)* | No tearing. It is also required for delta smoothing. |
| `application/run/max_fps` | `0` *(default)* | No cap, so the game follows the display (60/90/120/144 Hz). |
| `application/run/delta_smoothing` | `true` *(default)* | Filters timer noise out of the frame time when V-Sync is on. |
| `physics/common/physics_interpolation` | `true` | Nodes are drawn between the last two physics ticks, so motion is smooth at any refresh rate even though the logic runs at a fixed rate. It costs up to one tick (8.3 ms at 120 Hz) of display delay. |
| `physics/common/physics_jitter_fix` | `0.0` | Godot turns jitter fix off anyway when interpolation is on; set to 0 so it is clearly off. |
| Game logic in `_physics_process` | — | Movement uses a fixed 1/120 s step, so uneven frame times can't make motion uneven. It also makes every run exactly reproducible from its seed (the smoke test and captures rely on this). |
| Cosmetic tweens on a non-interpolated child | `physics_interpolation_mode = OFF` on `Player/Body` | Squash and stretch tweens run per rendered frame. Interpolating them as well would add lag. The parent still moves smoothly. |
| Teleports call `reset_physics_interpolation()` | — | Freshly spawned pipes and wrapped clouds would otherwise smear across the screen for one frame. |
| Follow-through | squash/stretch on hop and death, tilt that follows velocity, score pop, white flash on death, 0.1 s screen fades, card scale-in | Easing is a big part of what people call "smooth". |

## Instant

| Setting | Value | Why |
| --- | --- | --- |
| `physics/common/physics_ticks_per_second` | `120` | A tap affects the game on the next tick: 8.3 ms worst case instead of 16.7 ms at the default 60. It matches 120 Hz screens. The 2D logic is cheap, so the CPU cost is negligible. |
| `physics/common/max_physics_steps_per_frame` | `16` | At 120 ticks/s the default of 8 means the game visibly slows down once a frame takes more than 66 ms. 16 raises that to 133 ms. The docs recommend raising this together with the tick rate. |
| `input_devices/buffering/agile_event_flushing` | `true` | Android only. Touches are delivered before every physics tick, not once per frame, so a tap lands on the very next tick even when several ticks run in one frame. |
| React on finger-down | `InputEventScreenTouch.pressed` in the game; `TapButton` uses `ACTION_MODE_BUTTON_PRESS` | No waiting for the finger to lift. Typical taps last 50–100 ms, so this removes a lot of lag. |
| `input_devices/pointing/emulate_touch_from_mouse` | `true` | Desktop clicks arrive as touches, so the same code path is tested on desktop. |
| `input_devices/pointing/emulate_mouse_from_touch` | `true` *(default)* | Lets Control buttons receive touches. The game only listens to touch events, so nothing gets handled twice. |
| Retry | Restarts in place | No scene reload and no fade between runs. |
| Boot | `boot_splash/show_image=false`, splash color = sky color, no fade into the menu | No logo or color flash on start. |
| Game-over input guard | Buttons ignore taps for 0.4 s | Stops the last in-game tap from hitting Retry by accident. It protects the feel without making normal use slower. |
| `audio/driver/output_latency` | `15` ms *(default)* | Sound effects play together with the action. Lower values risk crackling on some phones. |
| Haptics | 15 ms on button press, 60 ms on death (Vibration setting) | Touch feedback reaches the player before the next frame does. |

## Not changed (and why)

- **Compatibility renderer:** The first prototype used it because it starts fast and runs everywhere, but it has no Android frame pacing. Mobile with automatic OpenGL fallback keeps compatibility. The cost is a slightly longer first launch while Vulkan builds its shader cache.
- **`application/run/frame_delay_msec`, `low_processor_mode`:** these are for desktop tools and would only add latency in a game.
- **Adaptive/Mailbox V-Sync:** desktop options with no effect on Android.

## How to verify on the phone

1. `make apk && make install`, then play for a minute.
2. Smoothness: `adb shell dumpsys SurfaceFlinger --timestats -enable`, play, then `adb shell dumpsys SurfaceFlinger --timestats -dump`. Look at the present-to-present histogram for the app's layer: almost every frame should be about 8.3 ms apart at 120 Hz.
3. Feel: play it side by side with a build of the same game in another engine, if you have one.

## Measured on a 120 Hz Android phone (2026-10-24)

SurfaceFlinger timestats, Android 16, 120 Hz display, during real play:

| App | Avg fps | Janky frames | Frame intervals at 8.3 ms | at 16.7 ms |
| --- | --- | --- | --- | --- |
| Template Hop (this template) | 117.4 | 0 | 95.2 % | 4.7 % |
| Unity Hop (same game in Unity) | 124.8 | 0 | 99.7 % | 0.2 % |

Playtest verdict after playing both: the Godot build felt clearly smoother and nicer than the Unity one.

### Swappy mode test (2026-10-24, follow-up)

Same phone, same scripted session (`adb shell input tap` every ~0.26 s for 60 s, ads/IAP off), SurfaceFlinger timestats split by display refresh rate. "On time" means the frame came exactly one vsync after the previous one.

| `swappy_mode` | Run | Time at 120 Hz | at 90 Hz | at 60 Hz | On time at 120 Hz |
| --- | --- | --- | --- | --- | --- |
| `auto_fps_auto_pipeline` (default) | 1 | 100 % (6,731 frames) | 0 | 0 | 94.4 % |
| `auto_fps_auto_pipeline` (default) | 2 | 100 % (6,721 frames) | 0 | 0 | 94.4 % |
| `pipeline_forced_on` | 1 | ~44 % | ~30 % | ~26 % | 99.1 % |
| `pipeline_forced_on` | 2 | ~42 % | ~3 % | ~54 % | 98.7 % |
| `pipeline_forced_on` + `max_fps=120` | 1 | ~42 % | ~3 % | ~54 % | 98.8 % |

(Time shares are computed from frames per rate: frames ÷ rate.)

Forced pipelining removes most skipped vsyncs, but it also lets Android run the display at 60 or 90 Hz for long stretches, which looks less smooth than 120 Hz with an occasional skipped frame. **Kept the default.** The ~5 % skipped vsyncs at 120 Hz remain; they did not register in the playtest feel test.
