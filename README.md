# WinDots (Windows Dotfiles)

Opinionated, Windows only dotfiles with:

- XDG-style layout rooted at `%USERPROFILE%` (`$HOME/.config` is enforced)
- Symlink-only linking with minimal, scoped elevation
- Reproducible package provisioning via a single Winget manifest
- Central PowerShell profile (shared between all tools like Visual Studio Code, PowerShell 5.x, and PowerShell 7.x)

## Table of Contents

- [WinDots (Windows Dotfiles)](#windots-windows-dotfiles)
  - [Table of Contents](#table-of-contents)
  - [Quick Start](#quick-start)
  - [What Bootstrap Does](#what-bootstrap-does)
  - [Updating](#updating)
  - [Repository Layout](#repository-layout)
  - [Winget Manifest](#winget-manifest)
  - [Audit \& Self-Test](#audit--self-test)
  - [Revert Examples](#revert-examples)
  - [PowerShell Profile](#powershell-profile)
  - [Extending](#extending)
  - [License](#license)

---

## Quick Start

One‑liner

```powershell
irm https://raw.githubusercontent.com/adityatrivedi/windots/main/bin/bootstrap.ps1 | iex
```

Already cloned / extracted:

```powershell
./bin/bootstrap.ps1 -ElevateLink -Verify -Quiet
```

Show help / options:

```powershell
./bin/bootstrap.ps1 -Help
```

Key bootstrap flags:

- `-ElevateLink` Elevate only if needed for symlink creation
- `-Verify` Run self-test at end
- `-Quiet` Suppress informational logs
- `-WhatIf` / `-Verbose` Standard PowerShell diagnostics where supported
- `-Help` (or `-?`) Show usage summary and exit

---

## What Bootstrap Does

1. Detects / enables Developer Mode (only that step may elevate)
2. Verifies functional non-admin symlink capability (falls back to elevated link if permitted)
3. Normalizes environment (sets `XDG_CONFIG_HOME`, ensures consistent `$HOME/.config`)
4. Installs Winget packages from manifest (idempotent, skip if already present)
5. Installs required PowerShell modules (PSReadLine, CompletionPredictor) in current user scope
6. Creates profile stubs that dot-source the central profile
7. Links repo `.config/*` into `$HOME/.config/*` via symbolic links

- Also ensures `%USERPROFILE%\.gitconfig` includes `~/.config/git/config` so Git reads the XDG config

8. Runs optional verification (`self-test.ps1`) if `-Verify`
9. Provides audit tooling to detect drift later (`audit.ps1`)

---

## Updating

**One-liner users:** Re-run the one-liner — it re-downloads the latest archive, overwrites `~/.dotfiles`, and re-runs bootstrap (fully idempotent):

```powershell
irm https://raw.githubusercontent.com/adityatrivedi/windots/main/bin/bootstrap.ps1 | iex
```

**Clone users:** Pull the latest changes and re-run bootstrap:

```powershell
git pull && ./bin/bootstrap.ps1 -ElevateLink -Verify
```

---

## Repository Layout

| Path / Script                  | Purpose                                                            |
| ------------------------------ | ------------------------------------------------------------------ |
| `bin/bootstrap.ps1`            | Orchestrates full setup; supports `-ElevateLink -Verify -Quiet`.   |
| `bin/install.ps1`              | Package installation from Winget manifest (including fonts).       |
| `bin/modules.ps1`              | Ensures required PS modules (current-user scope).                  |
| `bin/link.ps1`                 | Creates symlinks for all `.config` entries.                        |
| `bin/profile-setup.ps1`        | Installs PowerShell profile stubs.                                 |
| `bin/self-test.ps1`            | Post-setup validation (symlink, packages, modules, profile).       |
| `bin/audit.ps1`                | Drift detection vs. manifest (JSON or table output).               |
| `bin/revert.ps1`               | Selective or full cleanup (`-All`, supports `-WhatIf`).            |
| `bin/wt-theme.ps1`             | Windows Terminal theme export/import.                              |
| `bin/_common.ps1`              | Shared logging & helpers.                                          |
| `packages/windows-winget.json` | Canonical package ID list.                                         |
| `packages/windows-terminal-theme.json` | Exported Windows Terminal theme data.                    |
| `.config/`                     | Tool configuration directory (XDG-style).                          |

---

## Winget Manifest

Package manifest format supports both simple and extended entries:

```json
[
  { "id": "PackageName" },
  { "id": "PackageName2", "scope": "machine" }
]
```

- Default scope is `user` (no elevation required)
- Specify `"scope": "machine"` for packages that require machine-level installation
- Edit [windows-winget.json](./packages/windows-winget.json) to add/remove packages
- Run `./bin/install.ps1` to install new packages
- Run `./bin/audit.ps1` to verify current state

---

## Audit & Self-Test

Self-test highlights environment readiness. Audit focuses on package drift.

Audit outputs table or JSON (`-Json`) and exit codes:

- `0` OK
- `1` Drift / missing packages
- `2` Manifest or internal error

Examples:

```powershell
./bin/self-test.ps1
./bin/audit.ps1
./bin/audit.ps1 -Json | Out-File audit.json
```

---

## Revert Examples

Dry run everything:

```powershell
.\bin\revert.ps1 -All -WhatIf
```

Actual cleanup:

```powershell
.\bin\revert.ps1 -All
```

Selective (links only):

```powershell
.\bin\revert.ps1 -RemoveLinks
```

---

## PowerShell Profile

Central profile lives under `.config\powershell\profile.ps1` and initializes:

- Environment: `XDG_CONFIG_HOME`, `EDITOR`, `PAGER`
- Utility binaries: starship, zoxide, eza, bat (if present)
- Prompt & completions: Starship, PSReadLine, prediction source
- Safe module import wrapper & profile reload helper

Profile stubs (Documents profiles) simply dot-source this central file and are removed by `revert.ps1`.

---

## Extending

Add config: place under `.config\<tool>` → rerun `.\bin\link.ps1 -Force`.

Add package: modify manifest → run `.\bin\install.ps1` → verify with `.\bin\audit.ps1`.

Add initialization logic: extend central profile with guarded `Initialize-*` functions (keep vendor init isolated & optional).

---

## Windows Terminal Theme

Theme data (color schemes, UI themes, profile defaults for colorScheme and font) is stored in `packages/windows-terminal-theme.json` and applied automatically during bootstrap.

Export the theme from your current machine:

```powershell
./bin/wt-theme.ps1 -Export
```

Import on another machine (also runs during bootstrap):

```powershell
./bin/wt-theme.ps1 -Import
```

Revert (remove imported theme from Windows Terminal):

```powershell
.\bin\revert.ps1 -RevertTheme
```

---

## License

See [`LICENSE`](./LICENSE) for full text.
