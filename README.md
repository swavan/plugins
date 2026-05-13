# Swavan CLI

`swavan` is a command-line tool that installs, updates, and manages **plugins** — standalone binaries that extend host apps with new capabilities (Docker / Kubernetes management, AI terminal autocomplete, peer-to-peer sync, and more).

This repo (`swavan/plugins`) is the public artifact registry. It hosts:

- the `swavan` CLI binaries (one per platform)
- a [`catalog.json`](catalog.json) of available plugins
- per-plugin GitHub Releases that the CLI downloads from

---

## Install

### macOS / Linux

```sh
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/swavan/plugins/main/install.sh | sh
```

The script downloads the latest signed `swavan` binary for your platform, verifies its SHA-256 checksum, and installs it to `~/.local/bin/swavan`.

### Windows

```powershell
iwr -useb https://raw.githubusercontent.com/swavan/plugins/main/install.ps1 | iex
```

Installs to `%LOCALAPPDATA%\Programs\Swavan\bin\swavan.exe`.

### Custom install location

Set `SWAVAN_INSTALL_DIR` before running the installer:

```sh
SWAVAN_INSTALL_DIR=/usr/local/bin curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/swavan/plugins/main/install.sh | sh
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

Re-running the install script also works — it overwrites the existing binary.

### Update plugins

```sh
swavan plugin update                    # update everything
swavan plugin update swavan-container   # update one plugin
```

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
swavan plugin install swavan-container
```

The CLI fetches the latest release for your platform from `https://github.com/swavan/plugins/releases`, verifies the SHA-256 checksum, validates the bundled `manifest.json`, and unpacks the binary into the per-OS plugin directory shown above.

Pin a specific version:

```sh
swavan plugin install swavan-container --version 0.1.1
```

### List installed plugins

```sh
swavan plugin list
```

### Enable / disable

```sh
swavan plugin disable swavan-container   # keep files, stop loading it
swavan plugin enable  swavan-container
```

### Inspect / status / debug

```sh
swavan plugin inspect swavan-container   # manifest + JSON-RPC examples
swavan plugin status  swavan-container   # is the daemon running?
swavan plugin ping    swavan-container   # round-trip a status request
```

### Run as a standalone window

If a plugin's manifest sets `standalone.enabled = true`, you can launch its UI in its own native window without the host app:

```sh
swavan launch swavan-container
```

### Uninstall

```sh
swavan plugin uninstall swavan-container
```

---

## Available plugins

| Name | Description |
|---|---|
| [`swavan-container`](https://github.com/swavan/plugins/releases?q=swavan-container) | Docker and Kubernetes manager for Swavan SSH Studio |
| [`swavan-terminal-auto-complete`](https://github.com/swavan/plugins/releases?q=swavan-terminal-auto-complete) | AI-powered terminal autocomplete |

The full list lives in [`catalog.json`](catalog.json) and is the source of truth for `swavan plugin search`.

---

## Reporting issues

Open an issue at <https://github.com/swavan/plugins/issues>.
