# zon-releases

Public release repository for Zon products.

This repository is for distribution only. It contains installable artifacts and
user-facing documentation, not private source code or internal build logic.

## Available products

- `agent`: installs the `zon-agentd` binary

## Supported platforms

- macOS: `amd64`, `arm64`
- Linux: `amd64`, `arm64`
- Windows: `amd64`, `arm64`

## Install the latest agent release

Recommended user-local install:

```bash
curl -fsSL https://raw.githubusercontent.com/zoncaesaradmin/zon-releases/main/install.sh | \
  INSTALL_DIR="$HOME/.local/bin" bash
```

System-wide install:

```bash
curl -fsSL https://raw.githubusercontent.com/zoncaesaradmin/zon-releases/main/install.sh | \
  sudo env INSTALL_DIR=/usr/local/bin bash
```

Linux systemd install and start:

```bash
curl -fsSL https://raw.githubusercontent.com/zoncaesaradmin/zon-releases/main/install.sh | \
  sudo env INSTALL_DIR=/usr/local/bin INSTALL_SERVICE=1 START_SERVICE=1 bash
```

## Install a specific version

```bash
curl -fsSL https://raw.githubusercontent.com/zoncaesaradmin/zon-releases/main/install.sh | \
  PRODUCT=agent VERSION=v0.1.0 INSTALL_DIR="$HOME/.local/bin" bash
```

## Install from this public repo

No `GITHUB_TOKEN` is required. The installer downloads artifacts directly from:

```text
https://raw.githubusercontent.com/zoncaesaradmin/zon-releases/main/releases/agent/latest/
```

## Install to a custom directory

```bash
curl -fsSL https://raw.githubusercontent.com/zoncaesaradmin/zon-releases/main/install.sh | \
  PRODUCT=agent VERSION=latest INSTALL_DIR="$HOME/.local/bin" bash
```

## What the installer does

The installer:

1. detects your operating system and architecture
2. resolves the correct artifact under `releases/<product>/<version>/`
3. downloads `SHA256SUMS` and the matching binary
4. verifies the checksum by default
5. installs or updates the binary in `INSTALL_DIR`
6. optionally installs a Linux `systemd` service using fixed system paths
7. restarts an already-running Linux `systemd` service after an update

Default settings:

- `PRODUCT=agent`
- `VERSION=latest`
- `INSTALL_DIR=/usr/local/bin`
- `VERIFY_CHECKSUMS=1`
- `INSTALL_SERVICE=0`
- `START_SERVICE=0`
- `REPO_OWNER=zoncaesaradmin`
- `REPO_NAME=zon-releases`
- `REPO_REF=main`
- `SERVICE_NAME=zon-agentd`
- `SERVICE_ADDR=:8080`

Optional overrides:

- `BINARY_NAME`
- `BASE_URL`

## Linux service mode

On Linux systems with `systemd`, you can ask the installer to create and manage
`zon-agentd` as a service.

When Linux service mode is used, the installer manages these fixed paths for
you:

```text
Binary: /usr/local/bin/zon-agentd
Unit: /etc/systemd/system/zon-agentd.service
Log file: /var/log/zon/zon-agentd.log
Working directory: /var/lib/zon
```

If the directories or log file do not exist, the installer creates them.

Install the service but do not start it yet:

```bash
curl -fsSL https://raw.githubusercontent.com/zoncaesaradmin/zon-releases/main/install.sh | \
  sudo env INSTALL_DIR=/usr/local/bin INSTALL_SERVICE=1 bash
```

Install the service and start it immediately:

```bash
curl -fsSL https://raw.githubusercontent.com/zoncaesaradmin/zon-releases/main/install.sh | \
  sudo env INSTALL_DIR=/usr/local/bin INSTALL_SERVICE=1 START_SERVICE=1 bash
```

Manage the service:

```bash
sudo systemctl start zon-agentd.service
sudo systemctl stop zon-agentd.service
sudo systemctl restart zon-agentd.service
sudo systemctl status zon-agentd.service
```

If `systemd` is not present, the installer falls back to binary-only install.

## Upgrade behavior

The same `install.sh` command is used for both fresh installs and upgrades.

- Running the installer again downloads the current artifact from the selected
  `VERSION` path and replaces the installed binary.
- If a Linux `zon-agentd.service` already exists and is currently running, the
  installer restarts it after updating the binary.
- If `INSTALL_SERVICE=1` is used during an upgrade, the installer also refreshes
  the `systemd` unit definition and restarts the service if it was already
  active.
- If the service is installed but not running, it is left stopped unless
  `START_SERVICE=1` is provided.
- If Linux service mode is requested or already present, the installer uses the
  fixed system binary path `/usr/local/bin/zon-agentd`.

## Installed location

By default, the agent binary is installed to:

```text
/usr/local/bin/zon-agentd
```

If you set `INSTALL_DIR`, the binary is installed there instead. For a
user-local install, the binary path is usually:

```text
$HOME/.local/bin/zon-agentd
```

## Run it

After installation:

```bash
zon-agentd --help
```

If you installed to `$HOME/.local/bin`, make sure that directory is on your
`PATH`.

For Linux service installs, use `systemctl` instead of running the binary
directly.

## Logs

When run directly, logs are written to your terminal.

When installed as a Linux `systemd` service, the default log file is:

```text
/var/log/zon/zon-agentd.log
```

For manual runs, the installer suggests a user-writable log path for the
current platform, for example:

- macOS: `$HOME/Library/Logs/zon/zon-agentd.log`
- Linux without `systemd` service mode: `$HOME/.local/state/zon/zon-agentd.log`

## Uninstall

Remove the installed binary:

```bash
rm -f "$HOME/.local/bin/zon-agentd"
```

If you installed system-wide, remove `/usr/local/bin/zon-agentd` instead.
