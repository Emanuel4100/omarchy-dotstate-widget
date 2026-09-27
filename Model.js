function parseStatus(raw) {
  try {
    var parsed = JSON.parse(raw)
    if (!parsed || parsed.ok !== true) return { ok: false, lastError: "dotstate status script failed" }
    return parsed
  } catch (e) {
    return { ok: false, lastError: "Could not parse dotstate status" }
  }
}

// Same rules as status.py's redact(): dotstate's remote URL carries its token,
// and raw `dotstate sync` / helper stderr can echo it.
function redact(text) {
  return String(text || "")
    .replace(/(\b[a-z][a-z0-9+.-]*:\/\/)[^\/\s@]+@/gi, "$1***@")
    .replace(/\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})/g, "***")
}

function relativeTime(iso) {
  if (!iso) return "unknown"
  var then = Date.parse(iso)
  if (isNaN(then)) return "unknown"
  var seconds = Math.max(0, (Date.now() - then) / 1000)
  if (seconds < 45) return "just now"
  if (seconds < 90) return "a minute ago"
  var minutes = Math.round(seconds / 60)
  if (minutes < 45) return minutes + " minutes ago"
  var hours = Math.round(seconds / 3600)
  if (hours < 36) return hours + " hour" + (hours === 1 ? "" : "s") + " ago"
  var days = Math.round(seconds / 86400)
  return days + " day" + (days === 1 ? "" : "s") + " ago"
}

function aheadBehindText(ahead, behind) {
  ahead = Number(ahead) || 0
  behind = Number(behind) || 0
  if (ahead === 0 && behind === 0) return "Up to date with remote"
  var parts = []
  if (ahead > 0) parts.push(ahead + " ahead")
  if (behind > 0) parts.push(behind + " behind")
  return parts.join(", ")
}

function stateLabel(state, dirtyCount) {
  if (state === "error") return "Sync error"
  if (state === "syncing") return "Syncing…"
  if (state === "dirty") return dirtyCount > 0 ? (dirtyCount + " local change" + (dirtyCount === 1 ? "" : "s")) : "Ahead or behind remote"
  return "Synced"
}

function doctorFixHint(issue) {
  if (!issue.fixable) return ""
  var parts = []
  if (issue.fixAction) parts.push("Fix: " + issue.fixAction)
  if (issue.details && issue.details.length > 0) parts.push("(" + issue.details.join(", ") + ")")
  return parts.join(" ")
}

function fileStatusGlyph(file) {
  var code = (file.indexStatus !== " " ? file.indexStatus : file.worktreeStatus) || "?"
  if (code === "?") return "?"
  if (code === "A") return "+"
  if (code === "D") return "−"
  if (code === "R") return "→"
  return "±"
}
