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
5. installs the binary into `INSTALL_DIR`

Default settings:

- `PRODUCT=agent`
- `VERSION=latest`
- `INSTALL_DIR=/usr/local/bin`
- `VERIFY_CHECKSUMS=1`
- `REPO_OWNER=zoncaesaradmin`
- `REPO_NAME=zon-releases`
- `REPO_REF=main`

Optional overrides:

- `BINARY_NAME`
- `BASE_URL`

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

## Logs

When run directly, logs are written to your terminal. When run under a service
manager, logs are available through that service manager's normal logging
mechanism.

## Uninstall

Remove the installed binary:

```bash
rm -f "$HOME/.local/bin/zon-agentd"
```

If you installed system-wide, remove `/usr/local/bin/zon-agentd` instead.
