# Pomodoro Timer — Omarchy shell plugin

A `bar-widget` + `service` plugin for `omarchy-shell`: a live `MM:SS`
countdown in your bar, and clicking it opens a floating panel with a circular
progress ring, minute presets, a custom-duration input, and an auto-chaining
focus/break cycle (4 focus sessions -> long break, classic pomodoro).

The timer runs as a shared `service` engine (`TimerEngine.qml`) that the shell
instantiates once and every per-monitor bar widget / panel reads and drives, so
all screens show the same live countdown and any press on any screen controls
the same timer. State persists across reloads and restarts.

## Install

This repo is already pushed to GitHub, so install it on any machine with the
officially-documented one-liner:

```bash
omarchy plugin add https://github.com/heggrik/omarchy-pomodoro.git --enable
```

If you cloned it elsewhere and want to use your own fork instead, replace the
URL above with yours, and update the `id` in `manifest.json` (and the
`moduleName` in `BarWidget.qml` / `Panel.qml`) to match.

## Validate

```bash
PLUGIN_ID="io.github.heggrik.omarchy-pomodoro"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml" "$PLUGIN_DIR/TimerEngine.qml"
```

Both should exit clean. If `qmllint` complains about an import or an unknown
property, that's almost certainly a `Style`/`Color` token name that's drifted
from what the shell provides — see Troubleshooting.

## Using it

- **Left click** the bar widget: open/close the panel.
- **Right click** the bar widget: start/pause without opening the panel.
- Inside the panel: pick a preset (5 / 10 / 15 / 20 / 25 min), or type custom
  minutes (1-180) and hit **Set**. **Start/Pause**, **Reset**, **Skip** control
  the timer directly.
- The bar label keeps ticking down even with the panel closed — the engine
  keeps running in the background as long as `omarchy-shell` is alive.
- On completion: a short chime (`complete.wav`, bundled — played via
  `paplay`, `pw-play`, or `aplay` in that order) plus a `notify-send`
  notification, then it auto-advances to the next phase (break, or back to
  focus).
- The footer shows your progress through the current cycle (`n/4 cycle`) and a
  running `today` focus count, plus a **Sound on/off** toggle.

## Persistence

The engine saves its full state (phase, remaining time, running flag, session
counts, selected preset) to `~/.local/state/omarchy/pomodoro.json` on every
change, debounced, and re-hydrates it on startup. That means:

- A mid-flight countdown resumes where it left off after a shell restart.
- Your `today` focus count survives restarts.

Only the ambient sound preference is deliberately not persisted — it defaults
to on each launch.

## Hyprland keybinds (optional, in addition to bar clicks)

```ini
bind = SUPER, P, exec, omarchy-shell shell toggle io.github.heggrik.omarchy-pomodoro '{}'
bind = SUPER SHIFT, P, exec, omarchy-shell shell call io.github.heggrik.omarchy-pomodoro startPause ""
bind = SUPER SHIFT, N, exec, omarchy-shell shell call io.github.heggrik.omarchy-pomodoro skip ""
```

`startPause`, `skip`, and `reset` are also exposed on the bar widget, so they
can be driven without opening the panel.

## Configuring behavior

The knobs (`defaultMinutes`, `shortBreakMinutes`, `longBreakMinutes`,
`sessionsBeforeLongBreak`, `autoStartNext`) are `property` declarations at the
top of `TimerEngine.qml`. Edit them there and save — Quattro hot-reloads plugin
QML on save, no restart needed. (The panel reads and forwards these through the
shared engine, so TimerEngine.qml is the single source of truth.)

## Known limitations / good next steps

- **Do-not-disturb during focus** — not wired up yet; would call whatever
  notification daemon you run (`makoctl set-mode do-not-disturb` for mako).
- **Theming** — the ring, text, and borders derive from `bar.foreground` and
  `Color.accent`. If your bar's dark/light contrast looks off, that's the
  first thing to check.

## Troubleshooting

- **"entry point file not found"** from `omarchy plugin validate` — check
  capitalization; it must be exactly `BarWidget.qml` / `TimerEngine.qml`.
- **Validates but doesn't show up** — `omarchy-shell shell rescanPlugins`,
  then `omarchy plugin list --json | jq '.[] | select(.id | contains("pomodoro"))'`.
- **Listed but blank/broken in the bar** — `qs log -p "$OMARCHY_PATH/shell" --tail 100`
  for the actual QML error; most likely culprits are a `Style.*` or `Color.*`
  property name that differs from the shell, or `QtQuick.Layouts` not being in
  the shell's import path (if so, `Panel.qml` can be rewritten with plain
  `Row`/`Column` instead of `RowLayout`).
- **Panel opens once but not again** — this usually means `opened`, `open()`,
  `close()` aren't forwarding correctly between `BarWidget.qml` and
  `Panel.qml`; both already forward these here, but double check if you renamed
  anything.
