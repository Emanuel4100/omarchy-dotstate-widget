import json
import re
import subprocess
from pathlib import Path

STORAGE = Path.home() / ".config" / "dotstate" / "storage"
LOG_PATH = Path.home() / ".cache" / "dotstate" / "dotstate.log"

# Categories from `dotstate doctor --json` that duplicate what we already
# derive ourselves from git directly (Repository) or are never actionable
# from a bar widget (Environment, Configuration).
SKIP_DOCTOR_CATEGORIES = {"Repository", "Environment", "Configuration"}

ERROR_OR_WARN_RE = re.compile(r"\b(ERROR|WARN)\b")
SYNC_START_RE = re.compile(r"Starting sync operation")
SYNC_SUCCESS_RE = re.compile(r"Successfully pushed")


def run(command, cwd=None, timeout=6):
  try:
    completed = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    return completed.returncode, completed.stdout, completed.stderr
  except (OSError, subprocess.TimeoutExpired):
    return 1, "", ""


def git(*args):
  return run(["git", "-C", str(STORAGE)] + list(args))


def doctor():
  # A non-zero exit just means doctor found Warning/Error entries -- the
  # JSON on stdout is still complete, so parse it regardless of exit code.
  _, out, _ = run(["dotstate", "doctor", "--json"], timeout=10)
  try:
    return json.loads(out)
  except (json.JSONDecodeError, TypeError):
    return None


def active_profile_and_issues(doc):
  active_profile = ""
  issues = []
  if not doc:
    return active_profile, issues
  for result in doc.get("results", []):
    category = result.get("category", "")
    if category == "Configuration" and result.get("check_name") == "active_profile":
      match = re.search(r"'([^']+)'", result.get("message", ""))
      if match:
        active_profile = match.group(1)
    if category in SKIP_DOCTOR_CATEGORIES:
      continue
    status = result.get("status", "")
    if status in ("Error", "Warning"):
      details = result.get("details")
      issues.append({
        "category": category,
        "message": result.get("message", ""),
        "status": status,
        "fixable": bool(result.get("fixable", False)),
        "fixAction": result.get("fix_action", ""),
        "details": details if isinstance(details, list) else [],
      })
  return active_profile, issues


def dirty_files():
  code, out, _ = git("status", "--porcelain")
  if code != 0 or not out.strip():
    return []
  files = []
  for line in out.splitlines():
    if len(line) < 4:
      continue
    files.append({
      "path": line[3:],
      "indexStatus": line[0],
      "worktreeStatus": line[1],
    })
  return files


def ahead_behind():
  code, out, _ = git("rev-list", "--left-right", "--count", "HEAD...origin/main")
  if code != 0 or not out.strip():
    return 0, 0
  parts = out.split()
  if len(parts) != 2:
    return 0, 0
  try:
    return int(parts[0]), int(parts[1])
  except ValueError:
    return 0, 0


def last_remote_commit():
  for ref in ("origin/main", "HEAD"):
    code, out, _ = git("log", "-1", "--format=%cI%x00%s", ref)
    if code == 0 and out.strip():
      parts = out.strip().split("\x00", 1)
      ts = parts[0] if len(parts) > 0 else ""
      msg = parts[1] if len(parts) > 1 else ""
      return ts, msg
  return "", ""


def last_log_error():
  if not LOG_PATH.exists():
    return ""
  try:
    lines = LOG_PATH.read_text(encoding="utf-8", errors="replace").splitlines()
  except OSError:
    return ""
  tail = lines[-200:]
  last_start = -1
  for i, line in enumerate(tail):
    if SYNC_START_RE.search(line):
      last_start = i
  if last_start == -1:
    return ""
  after = tail[last_start:]
  synced_since_start = False
  last_error_line = ""
  for line in after:
    if SYNC_SUCCESS_RE.search(line):
      synced_since_start = True
    elif ERROR_OR_WARN_RE.search(line):
      last_error_line = line.strip()
  return "" if synced_since_start else last_error_line


def main():
  doc = doctor()
  active_profile, doctor_issues = active_profile_and_issues(doc)
  files = dirty_files()
  ahead, behind = ahead_behind()
  remote_ts, remote_msg = last_remote_commit()
  last_error = last_log_error()

  if last_error or any(issue["status"] == "Error" for issue in doctor_issues):
    state = "error"
  elif files or ahead or behind:
    state = "dirty"
  else:
    state = "synced"

  print(json.dumps({
    "ok": True,
    "state": state,
    "activeProfile": active_profile,
    "dirtyFiles": files,
    "ahead": ahead,
    "behind": behind,
    "lastRemoteCommitTs": remote_ts,
    "lastRemoteCommitMsg": remote_msg,
    "doctorIssues": doctor_issues,
    "lastError": last_error,
  }))


if __name__ == "__main__":
  main()
