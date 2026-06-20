# Swavan CLI

`swavan` is a command-line tool that installs, updates, and manages **plugins** — standalone binaries that extend host apps with new capabilities (Docker / Kubernetes management, AI terminal autocomplete, peer-to-peer sync, AppRelay screen sharing, and more).

This repo (`swavan/plugins`) is the public artifact registry. It hosts:

- the `swavan` CLI binaries (one per platform)
- a [`catalog.json`](catalog.json) of available plugins
- per-plugin GitHub Releases that the CLI downloads from

---

## Install

### macOS / Linux

```sh
curl -fsSL https://raw.githubusercontent.com/swavan/plugins/main/install.sh | sh
```

Downloads the latest signed `swavan` binary for your platform, verifies its SHA-256 checksum, and installs every binary in the tarball (`swavan` + sibling tools like `swavan-plugin-shell`) into `~/.local/bin/`.

### Windows

```powershell
irm https://raw.githubusercontent.com/swavan/plugins/main/install.ps1 | iex
```

Installs to `%LOCALAPPDATA%\Programs\Swavan\bin\swavan.exe`.

### Custom install location

Set `SWAVAN_INSTALL_DIR` before running the installer:

```sh
# macOS / Linux
SWAVAN_INSTALL_DIR=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/swavan/plugins/main/install.sh | sh
```

```powershell
# Windows
$env:SWAVAN_INSTALL_DIR = "C:\Tools\swavan"
irm https://raw.githubusercontent.com/swavan/plugins/main/install.ps1 | iex
```

### Manual download

Pre-built archives for every platform are attached to each release: <https://github.com/swavan/plugins/releases/latest>.

Make sure the install directory is on your `PATH`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Verify:

```sh
swavan --help
```

---

## Commands at a glance

```
swavan plugin       Manage plugins (install/list/enable/disable/inspect/update/...)
swavan launch       Open a plugin in its own native window (standalone mode)
swavan apprelay     Manage AppRelay server integration
swavan update       Update installed plugins to the latest version
swavan self-update  Update the swavan CLI itself
swavan completions  Print a shell completion script
```

Run any of them with `--help` for full options.

---

## Shell completion

`swavan` ships scripts for bash, zsh, fish, PowerShell, and elvish. Pick the one that matches your shell:

```sh
# zsh — make sure your fpath picks up ~/.zfunc, then:
swavan completions zsh > "${fpath[1]}/_swavan"

# bash
swavan completions bash | sudo tee /usr/local/etc/bash_completion.d/swavan >/dev/null

# fish
swavan completions fish > ~/.config/fish/completions/swavan.fish
```

```powershell
# PowerShell
swavan completions powershell | Out-String | Invoke-Expression
# (or append the output to your $PROFILE for persistence)
```

Restart the shell after installing. Tab-complete any subcommand to verify:

```sh
swavan plugin <TAB>
```

---

## Update

### Update the CLI itself

```sh
swavan self-update
```

Re-running the install script also works — it overwrites the existing binaries.

### Update plugins

```sh
swavan update                           # update every installed plugin
swavan plugin update                    # same thing, longer form
swavan plugin update conto   # update a single plugin
```

The CLI fetches the latest release that satisfies each plugin's `min_app_version` constraint — outdated CLIs stay on the last compatible plugin release rather than pulling a version that needs a newer host.

---

## Uninstall

### Remove the CLI

```sh
rm "$(which swavan)"
```

(or `del "%LOCALAPPDATA%\Programs\Swavan\bin\swavan.exe"` on Windows.)

### Remove all plugin data

Plugins live under a per-OS data directory:

| OS | Path |
|---|---|
| macOS | `~/Library/Application Support/ssh-studio.swavan.com/plugins/` |
| Linux | `~/.local/share/ssh-studio.swavan.com/plugins/` |
| Windows | `%APPDATA%\ssh-studio.swavan.com\plugins\` |

Delete the directory to remove every installed plugin and its state.

---

## Add a plugin

### Browse the catalog

```sh
swavan plugin search              # list everything in the public catalog
swavan plugin search container    # filter by substring
```

The catalog is sourced from [`catalog.json`](catalog.json) in this repo.

### Install

```sh
swavan plugin install conto
```

The CLI fetches the latest release for your platform from `https://github.com/swavan/plugins/releases`, verifies the SHA-256 checksum, validates the bundled `manifest.json` (including `min_app_version`), and unpacks the binary + UI into the per-OS plugin directory shown above.

Pin a specific version:

```sh
swavan plugin install conto --version 0.1.2
```

### List installed plugins

```sh
swavan plugin list
```

### Enable / disable

```sh
swavan plugin disable conto   # keep files, stop loading it
swavan plugin enable  conto
```

### Daemon controls

Most plugins ship a long-running daemon. The host app starts it on demand, but you can also drive it manually for debugging:

```sh
swavan plugin start-daemon conto
swavan plugin stop-daemon  conto
swavan plugin status       conto   # is the daemon running?
swavan plugin ping         conto   # round-trip a status JSON-RPC call
```

### Inspect

```sh
swavan plugin inspect conto   # manifest + example JSON-RPC calls
```

### Reconcile state

If you've moved files around by hand, ask the CLI to resync its database with what's actually on disk:

```sh
swavan plugin sync
```

### Run as a standalone window

If a plugin's manifest sets `standalone.enabled = true`, you can launch its UI in its own native window without the host app:

```sh
swavan launch conto
```

The window is hosted by `swavan-plugin-shell` (installed alongside the CLI) — a Tauri-based shell that owns the daemon lifecycle, forwards JSON-RPC + push events to the renderer, and follows the OS light/dark theme. Useful for headless dev environments and for plugins that don't need to be embedded in SSH Studio.

### Uninstall

```sh
swavan plugin uninstall conto
```

---

## Available plugins

| Name | Description |
|---|---|
| [`conto`](https://github.com/swavan/plugins/releases?q=conto) | Docker and Kubernetes manager for Swavan |
| [`swavan-terminal-auto-complete`](https://github.com/swavan/plugins/releases?q=swavan-terminal-auto-complete) | AI-powered terminal autocomplete |

The full list lives in [`catalog.json`](catalog.json) and is the source of truth for `swavan plugin search`.

---

## Reporting issues

Open an issue at <https://github.com/swavan/plugins/issues>.
