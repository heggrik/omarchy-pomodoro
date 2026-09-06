import QtQuick
import Quickshell
import Quickshell.Io

// Single shared pomodoro engine. The shell instantiates this once (service
// kind) and every per-monitor bar widget / panel reads and drives it through
// this one instance, so there is never more than one active timer.
//
// State survives reloads and restarts via ~/.local/state/omarchy/pomodoro.json —
// a debounced save timer flushes it on any change, and it is re-hydrated on
// startup (resuming a mid-flight countdown where it left off).
Item {
  id: root

  // ---- config -----------------------------------------------------
  readonly property var presetMinutes: [5, 10, 15, 20, 25]
  property int defaultMinutes: 25
  property int shortBreakMinutes: 5
  property int longBreakMinutes: 15
  property int sessionsBeforeLongBreak: 4
  property bool autoStartNext: false

  // ---- state --------------------------------------------------------
  property string phase: "focus"          // focus | short_break | long_break
  property int totalSeconds: defaultMinutes * 60
  property int remainingSeconds: defaultMinutes * 60
  property bool running: false
  property int focusSessionsDone: 0
  property int todayFocusCount: 0
  property int selectedPreset: defaultMinutes

  // Sound preference is deliberately not persisted.
  property bool soundEnabled: true

  readonly property real progressFraction: totalSeconds > 0
    ? 1 - (remainingSeconds / totalSeconds) : 0

  readonly property string phaseLabel: phase === "focus" ? "Focus"
    : phase === "short_break" ? "Short break" : "Long break"

  readonly property string barLabel: {
    var m = Math.floor(Math.max(0, remainingSeconds) / 60)
    var s = Math.max(0, remainingSeconds) % 60
    var pad = function(n) { return n < 10 ? "0" + n : "" + n }
    return pad(m) + ":" + pad(s)
  }

  // ---- public actions ----------------------------------------------
  function startPause() {
    if (running) pauseTimer()
    else startTimer()
  }

  function skip() {
    pauseTimer()
    advancePhase()
  }

  function reset() {
    pauseTimer()
    remainingSeconds = totalSeconds
  }

  function setPhaseLength(minutes) {
    // Selecting a preset starts a fresh focus phase, matching the original
    // panel behavior where both call sites set phase = "focus" first.
    phase = "focus"
    selectedPreset = minutes
    totalSeconds = minutes * 60
    remainingSeconds = totalSeconds
  }

  // ---- timer engine -------------------------------------------------
  function startTimer() {
    if (running) return
    running = true
    tickTimer.start()
  }

  function pauseTimer() {
    running = false
    tickTimer.stop()
  }

  function advancePhase() {
    if (phase === "focus") {
      focusSessionsDone += 1
      todayFocusCount += 1
      if (focusSessionsDone % sessionsBeforeLongBreak === 0) {
        phase = "long_break"
        totalSeconds = longBreakMinutes * 60
      } else {
        phase = "short_break"
        totalSeconds = shortBreakMinutes * 60
      }
    } else {
      phase = "focus"
      totalSeconds = selectedPreset * 60
    }
    remainingSeconds = totalSeconds
  }

  function onPhaseComplete() {
    pauseTimer()
    var finishedPhase = phase
    if (soundEnabled) {
      Quickshell.execDetached(["sh", "-c",
        "paplay '" + rootDir + "/complete.wav' " +
        "|| pw-play '" + rootDir + "/complete.wav' " +
        "|| aplay -q '" + rootDir + "/complete.wav'"])
    }
    Quickshell.execDetached(["notify-send", "-a", "Pomodoro",
      finishedPhase === "focus" ? "Focus complete" : "Break complete",
      "Time for the next phase."])
    advancePhase()
    if (autoStartNext) startTimer()
  }

  readonly property string rootDir: {
    var url = Qt.resolvedUrl("complete.wav")
    var p = url.toString().replace("file://", "")
    var idx = p.lastIndexOf("/")
    return idx >= 0 ? p.substring(0, idx) : p
  }

  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    onTriggered: {
      remainingSeconds -= 1
      if (remainingSeconds <= 0) root.onPhaseComplete()
    }
  }

  // ---- persistence ---------------------------------------------------

  readonly property string stateHome: Quickshell.env("HOME") + "/.local/state"
  readonly property string settingsDir: stateHome + "/omarchy"
  readonly property string settingsPath: settingsDir + "/pomodoro.json"

  property bool _hydrating: false
  property bool settingsLoaded: false

  // Schedule a save whenever the engine state changes.
  onPhaseChanged: root.scheduleSettingsSave()
  onTotalSecondsChanged: root.scheduleSettingsSave()
  onRemainingSecondsChanged: root.scheduleSettingsSave()
  onRunningChanged: root.scheduleSettingsSave()
  onFocusSessionsDoneChanged: root.scheduleSettingsSave()
  onTodayFocusCountChanged: root.scheduleSettingsSave()
  onSelectedPresetChanged: root.scheduleSettingsSave()

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    // Missing file (first run): an empty string means "fresh defaults".
    onLoadFailed: root.loadSettings("")
  }

  Timer {
    id: saveTimer
    interval: 500
    repeat: false
    onTriggered: root.flushSettings()
  }

  function scheduleSettingsSave() {
    if (!root.settingsLoaded || root._hydrating) return
    saveTimer.restart()
  }

  function flushSettings() {
    settingsFile.setText(JSON.stringify({
      version: 1,
      phase: root.phase,
      totalSeconds: root.totalSeconds,
      remainingSeconds: root.remainingSeconds,
      running: root.running,
      focusSessionsDone: root.focusSessionsDone,
      todayFocusCount: root.todayFocusCount,
      selectedPreset: root.selectedPreset
    }, null, 2) + "\n")
  }

  function loadSettings(raw) {
    if (root.settingsLoaded) return

    var parsed = {}
    if (raw && String(raw).trim()) {
      try { parsed = JSON.parse(raw) } catch (e) {
        console.warn("pomodoro: settings parse failed:", e)
        parsed = {}
      }
    }

    root._hydrating = true
    if (typeof parsed.phase === "string" &&
        ["focus", "short_break", "long_break"].indexOf(parsed.phase) !== -1)
      root.phase = parsed.phase
    if (typeof parsed.totalSeconds === "number" && isFinite(parsed.totalSeconds) && parsed.totalSeconds >= 0)
      root.totalSeconds = parsed.totalSeconds
    if (typeof parsed.remainingSeconds === "number" && isFinite(parsed.remainingSeconds) && parsed.remainingSeconds >= 0)
      root.remainingSeconds = parsed.remainingSeconds
    if (typeof parsed.running === "boolean")
      root.running = parsed.running
    if (typeof parsed.focusSessionsDone === "number" && isFinite(parsed.focusSessionsDone))
      root.focusSessionsDone = parsed.focusSessionsDone
    if (typeof parsed.todayFocusCount === "number" && isFinite(parsed.todayFocusCount))
      root.todayFocusCount = parsed.todayFocusCount
    if (typeof parsed.selectedPreset === "number" && isFinite(parsed.selectedPreset))
      root.selectedPreset = parsed.selectedPreset
    root._hydrating = false
    root.settingsLoaded = true

    // Resume a timer that was mid-flight when the shell stopped. The
    // remaining-time snapshot is preserved, so the countdown carries on.
    if (root.running) tickTimer.start()
  }

  Component.onCompleted: {
    // Ensure the state dir exists, then load. Creating the file (even empty)
    // lets FileView.onLoaded fire reliably; absent a file, onLoadFailed
    // hands us an empty string, which loadSettings treats as defaults.
    Quickshell.execDetached(["sh", "-c",
      "mkdir -p '" + root.settingsDir + "' && " +
      "touch '" + root.settingsPath + "'"])
    Qt.callLater(function() { settingsFile.reload() })
  }
}