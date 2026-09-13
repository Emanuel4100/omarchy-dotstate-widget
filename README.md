# Dotstate — Omarchy bar widget

Shows [dotstate](https://github.com/Emanuel4100/dotstate-storage) sync status
in the Omarchy 4 top bar: whether your dotfiles repo is synced, has local
changes, or has a sync error, plus a popup with the details and a manual
sync action.

## Features

- Bar icon reflects state at a glance: synced / local changes / syncing / error
- **Left-click**: open the popup
- **Right-click**: force a refresh
- Popup shows:
  - Active dotstate profile
  - Ahead/behind commit count vs the remote
  - Last remote update (relative time + commit message)
  - List of locally changed files
  - Any `dotstate doctor` warnings/errors, with their suggested fix
  - A **Sync Now** button that runs `dotstate sync`
- Sends a desktop notification the moment a sync error first appears
  (not on every poll)

## Requirements

- [dotstate](https://github.com/Emanuel4100/dotstate-storage) installed and
  configured (`dotstate doctor` should run cleanly)
- Python 3 (stdlib only, no extra packages)
- `git` and `notify-send` on `PATH`

## Install

```
omarchy plugin add https://github.com/Emanuel4100/omarchy-dotstate-widget --enable
```

Or manually:

```
git clone https://github.com/Emanuel4100/omarchy-dotstate-widget ~/.config/omarchy/plugins/dotstate
omarchy plugin enable dotstate --section right
omarchy-shell shell rescanPlugins
```

## Update

```
omarchy plugin update dotstate
```

## Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `refreshIntervalSec` | integer | `60` | How often to poll dotstate status |

## How it works

`status.py` shells out to `dotstate doctor --json` and `git -C
~/.config/dotstate/storage status/log/rev-list` to build one status JSON
blob (never reads `dotstate`'s config file directly, since that can contain
a plaintext remote token). `Service.qml` polls it on a timer and exposes the
result to `Panel.qml`, which draws the bar icon and popup.
