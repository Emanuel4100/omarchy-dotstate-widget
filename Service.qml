import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property string state: "synced"
  property string activeProfile: ""
  property var dirtyFiles: []
  property int ahead: 0
  property int behind: 0
  property string lastRemoteCommitTs: ""
  property string lastRemoteCommitMsg: ""
  property var doctorIssues: []
  property string lastError: ""
  property string actionStatus: ""

  // Optimistic "syncing" overlay: set the instant Sync Now is clicked so the
  // icon reacts immediately, cleared once the post-sync refresh lands.
  property bool syncing: false
  readonly property string displayState: syncing ? "syncing" : state
  readonly property bool busy: statusProcess.running || syncProcess.running || syncing

  // Edge-triggered so a notification fires once per new error, not on every
  // periodic poll while the error persists.
  property bool _wasError: false

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 60, 10, 3600)
  // Resolved relative to this file's own location rather than a hardcoded
  // plugin directory name -- `omarchy plugin add` clones by manifest id
  // (e.g. `emanuel.dotstate`), not by this repo's folder name, so a
  // hardcoded path breaks on every machine but the one it was typed on.
  readonly property string helperPath: String(Qt.resolvedUrl("status.py")).replace(/^file:\/\//, "")

  property string _statusOutput: ""
  property string _statusError: ""
  property string _syncOutput: ""
  property string _syncError: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  function elide(text) {
    var value = String(text || "").replace(/\s+/g, " ").trim()
    return value.length > 220 ? value.substring(0, 217) + "…" : value
  }

  function refresh() {
    if (statusProcess.running) return
    _statusOutput = ""
    _statusError = ""
    statusProcess.command = ["python3", helperPath]
    statusProcess.running = true
  }

  function applyStatus(raw) {
    var parsed = Model.parseStatus(raw)
    if (parsed.ok !== true) {
      lastError = parsed.lastError || "Failed to read dotstate status"
      noteErrorEdge(true)
      return
    }
    state = String(parsed.state || "synced")
    activeProfile = String(parsed.activeProfile || "")
    dirtyFiles = parsed.dirtyFiles || []
    ahead = Number(parsed.ahead || 0)
    behind = Number(parsed.behind || 0)
    lastRemoteCommitTs = String(parsed.lastRemoteCommitTs || "")
    lastRemoteCommitMsg = String(parsed.lastRemoteCommitMsg || "")
    doctorIssues = parsed.doctorIssues || []
    lastError = String(parsed.lastError || "")
    noteErrorEdge(state === "error")
  }

  function noteErrorEdge(isError) {
    if (isError && !_wasError) notifyError()
    _wasError = isError
  }

  function notifyError() {
    var body = lastError !== "" ? lastError : (doctorIssues.length > 0 ? doctorIssues[0].message : "Dotstate sync needs attention")
    Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Dotstate", "Dotstate sync error", elide(body)])
  }

  function sync() {
    if (busy) return
    syncing = true
    actionStatus = "Syncing…"
    _syncOutput = ""
    _syncError = ""
    syncProcess.command = ["dotstate", "sync"]
    syncProcess.running = true
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: postSyncRefresh
    interval: 800
    repeat: false
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true; onStreamFinished: root._statusOutput = text }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true; onStreamFinished: root._statusError = text }
    onExited: function(exitCode) {
      var stdout = String(statusStdout.text || root._statusOutput || "")
      var stderr = String(statusStderr.text || root._statusError || "")
      if (stdout !== "") root.applyStatus(stdout)
      else {
        root.lastError = root.elide(stderr || "Could not read dotstate status")
        root.noteErrorEdge(true)
      }
    }
  }

  Process {
    id: syncProcess
    running: false
    command: []
    stdout: StdioCollector { id: syncStdout; waitForEnd: true; onStreamFinished: root._syncOutput = text }
    stderr: StdioCollector { id: syncStderr; waitForEnd: true; onStreamFinished: root._syncError = text }
    onExited: function(exitCode) {
      root.syncing = false
      var stdout = String(syncStdout.text || root._syncOutput || "")
      var stderr = String(syncStderr.text || root._syncError || "")
      if (exitCode !== 0) {
        root.actionStatus = root.elide(stderr || stdout || "dotstate sync failed")
      } else {
        root.actionStatus = ""
      }
      postSyncRefresh.restart()
    }
  }
}
