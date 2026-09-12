# Building

Export presets live in `export_presets.cfg` and are committed, so a build is
reproducible. They hold no secrets: the Android keystore path and password come
from environment variables at export time.

Engine: **Godot 4.7.2-stable**. Renderer: Mobile. ETC2 ASTC texture import is on
in `project.godot` because arm64 targets (macOS universal, Android, iOS) refuse
to export without it.

## One-time setup

**Export templates** — required for every target, about 1.2 GB:

```bash
curl -L -o /tmp/templates.tpz \
  https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
mkdir -p "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
unzip -q /tmp/templates.tpz -d /tmp/tpl
mv /tmp/tpl/templates/* "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/"
```

**Android only** — Godot reads two paths from its editor settings
(`~/Library/Application Support/Godot/editor_settings-4.7.tres`):

| Setting | Value on this machine |
|---|---|
| `export/android/android_sdk_path` | `~/Library/Android/sdk` |
| `export/android/java_sdk_path` | `/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home` |

Godot 4.7 wants **JDK 17**. Set these in the editor under
*Editor Settings → Export → Android*, or edit that file directly.

## Exporting

```bash
# Desktop
godot --headless --export-release "Linux" build/linux/deja-mort.x86_64
godot --headless --export-release "macOS" build/macos/deja-mort.app

# Android (debug-signed, arm64)
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/.android/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
godot --headless --export-debug "Android" build/android/deja-mort.apk
```

`build/` is gitignored. The presets exclude `docs/`, `tests/`, `tools/` and the
gdUnit4 addon from the pack — none of it is needed at runtime.

## Verifying an Android build

```bash
BT=$(ls -d "$HOME/Library/Android/sdk"/build-tools/* | sort -V | tail -1)
"$BT/apksigner" verify --print-certs build/android/deja-mort.apk
"$BT/aapt2" dump badging build/android/deja-mort.apk | head -2
```

## Icons

The project icon, the macOS `.icns` and the Android legacy launcher icon are all
`assets/brand/app-icon-1024.png`. Android's two adaptive layers are generated
from the delivered art and the brand token:

```bash
godot --headless -s tools/make_icon_layers.gd
```

It rewrites `assets/brand/icon-adaptive-{foreground,background}-1024.png` and the
composite preview in `docs/screenshots/`. Re-run it if the mark or `Brand.BG_DARK`
ever changes.

## Screenshots

`docs/screenshots/` holds the evidence for presentation changes, produced by:

```bash
godot --path . -s tools/capture.gd -- wheel_fridge 2.0 --cell 2,2
godot --path . -s tools/capture.gd -- win_screen 85 --speed 10 --solution kill_toaster
```

The capture tool is not headless — Godot's headless driver has no renderer, so
it opens a window. It prints sim state alongside the image, because a screenshot
on its own cannot prove the loop actually ran.

## Reading a playtest

A debug build records the session: every tap with what it resolved to, every
action with whether the sim took it, every event off the bus, and how each loop
ended. One JSON object per line, in `user://logs/session-<stamp>.jsonl`. A
shipped build records nothing — `log.session` in `content/visuals.json` gates it
and `OS.is_debug_build()` gates that.

```bash
godot --headless -s tools/session_report.gd            # the newest session
godot --headless -s tools/session_report.gd -- --list  # what is there
godot --headless -s tools/session_report.gd -- user://logs/session-20260912-170800.jsonl
```

The report counts taps, actions, refusals and endings per loop, and calls out the
two things that mean something went wrong: **taps that resolved to nothing** —
the player clicked and the game did not even offer a wheel — and **the same
refusal three times or more**, which is a player fighting the game rather than
learning it.

