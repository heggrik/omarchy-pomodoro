# Pomodoro Timer — Omarchy (Quattro) shell plugin

A `bar-widget` + panel plugin for `omarchy-shell`: a live countdown in your
bar, and clicking it opens a floating panel with a circular progress ring,
minute presets, a custom-duration input, and an auto-chaining focus/break
cycle (4 focus sessions -> long break, classic pomodoro).

This is real QML built against the documented Quattro plugin contract
(`bar-widget` cloned-clock pattern) — but it has **not been run against a
live Omarchy install**, since I don't have one to test on. Validate it
before trusting it, and see Troubleshooting below if something's off.

## Fastest install (no GitHub repo needed)

```bash
chmod +x install.sh
./install.sh              # uses your $USER as the id suffix
# or: ./install.sh someusername
```

This copies the plugin into `~/.config/omarchy/plugins/io.github.<you>.pomodoro-timer/`,
swaps in that id everywhere it's referenced, validates it, rescans plugins,
and enables it — all in one step. This is the officially-documented
"installing by hand" path (a plain folder drop, no git required), just
scripted.

## Proper install via `omarchy plugin add`

If you want the real thing — one command, updatable, shareable:

1. Push this folder as its own git repo, e.g.:
   ```bash
   cd pomodoro-omarchy-plugin
   git init && git add . && git commit -m "Pomodoro timer plugin"
   gh repo create pomodoro-timer-omarchy --public --source=. --push
   # or create the repo on GitHub manually and `git remote add origin ...; git push`
   ```
2. Before pushing, replace every `io.github.yourname.pomodoro-timer` in
   `manifest.json`, `BarWidget.qml`, and `Panel.qml` with your real id
   (e.g. `io.github.<your-username>.pomodoro-timer`), and update `author`
   in `manifest.json`.
3. Then, on any machine:
   ```bash
   omarchy plugin add https://github.com/<you>/pomodoro-timer-omarchy.git --enable
   ```

That's the one-liner you were picturing — it just needs the repo to exist
first, since `omarchy plugin add` clones from git.

## Validate first

```bash
PLUGIN_ID="io.github.<you>.pomodoro-timer"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
```

Both should exit clean. If `qmllint` complains about an import or an
unknown property, that's almost certainly a `Style`/`Color` token name
that's drifted from what I assumed — see Troubleshooting.

## Using it

- **Left click** the bar widget: open/close the panel.
- **Right click** the bar widget: start/pause without opening the panel.
- Inside the panel: pick a preset, or type custom minutes and hit **Set**.
  **Start/Pause**, **Reset**, **Skip** control the timer directly.
- The bar label keeps ticking down even with the panel closed — the timer
  runs in the background as long as `omarchy-shell` is alive.
- On completion: a short chime (`complete.wav`, already bundled — no
  runtime generation needed) plus a `notify-send` notification, then it
  auto-advances to the next phase (break, or back to focus).

## Hyprland keybinds (optional, in addition to bar clicks)

```ini
bind = SUPER, P, exec, omarchy-shell shell toggle io.github.<you>.pomodoro-timer '{}'
bind = SUPER SHIFT, P, exec, omarchy-shell shell call io.github.<you>.pomodoro-timer startPause ""
bind = SUPER SHIFT, N, exec, omarchy-shell shell call io.github.<you>.pomodoro-timer skip ""
```

## Configuring behavior

The knobs (`shortBreakMinutes`, `longBreakMinutes`, `sessionsBeforeLongBreak`,
`autoStartNext`, `defaultMinutes`) are `property` declarations at the top of
`Panel.qml`. Edit them directly and save — Quattro hot-reloads plugin QML
on save, no restart needed.

## Known limitations / good next steps

- **Session stats reset on shell restart** — `todayFocusCount` lives in
  memory only. Persisting it needs a `Quickshell.Io` `FileView` (or a
  small helper script) writing to e.g.
  `~/.cache/pomodoro-timer/stats.json`; happy to add that once the basic
  plugin is confirmed working on your machine.
- **Do-not-disturb during focus** — not wired up yet; would call whatever
  notification daemon you run (`makoctl set-mode do-not-disturb` for mako).
- **Theming** — the ring, text, and borders derive from `root.barForeground`
  (same token the built-in clock panel uses) and `Color.accent`. If your
  bar's dark/light contrast looks off, that's the first thing to check.

## Troubleshooting

- **"entry point file not found"** from `omarchy plugin validate` — check
  capitalization; it must be exactly `BarWidget.qml`.
- **Validates but doesn't show up** — `omarchy-shell shell rescanPlugins`,
  then `omarchy plugin list --json | jq '.[] | select(.id | contains("pomodoro"))'`.
- **Listed but blank/broken in the bar** — `qs log -p "$OMARCHY_PATH/shell" --tail 100`
  for the actual QML error, and send it my way — most likely culprits are
  a `Style.*` or `Color.*` property name I guessed wrong, or `QtQuick.Layouts`
  not being in the shell's import path (if so, tell me and I'll rewrite the
  layout with plain `Row`/`Column` instead of `RowLayout`).
- **Panel opens once but not again** — this usually means `opened`,
  `open()`, `close()` aren't forwarding correctly between `BarWidget.qml`
  and `Panel.qml`; both already forward these here, but if you renamed
  anything double check that.

## Fallback: standalone version

If the Quattro plugin route hits a wall, there's also a completely
standalone GTK4 layer-shell version of this timer (same features, runs as
its own process instead of inside `omarchy-shell`) — ask and I'll hand
that back over.
