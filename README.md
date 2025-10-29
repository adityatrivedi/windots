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

ZIP (no Git needed):

```powershell
$zipUrl = 'https://github.com/adityatrivedi/windots/archive/refs/heads/main.zip'
Invoke-WebRequest $zipUrl -OutFile dotfiles.zip; Expand-Archive dotfiles.zip -DestinationPath $HOME\.dotfiles -Force
$HOME\.dotfiles\bin\bootstrap.ps1 -RepoZipUrl $zipUrl -ElevateLink -Verify -Quiet
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

- `-RepoZipUrl <URL>` Download & extract on the fly (no Git requirement)
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
6. Installs Cascadia Code Nerd Font (user scope) if missing
7. Creates profile stubs that dot-source the central profile
8. Links repo `.config/*` into `$HOME/.config/*` via symbolic links

- Also ensures `%USERPROFILE%\.gitconfig` includes `~/.config/git/config` so Git reads the XDG config

9. Runs optional verification (`self-test.ps1`) if `-Verify`
10. Provides audit tooling to detect drift later (`audit.ps1`)

---

## Repository Layout

| Path / Script                  | Purpose                                                            |
| ------------------------------ | ------------------------------------------------------------------ |
| `bin/bootstrap.ps1`            | Orchestrates full setup; supports `-ElevateLink -Verify -Quiet`.   |
| `bin/install.ps1`              | Package installation from Winget manifest.                         |
| `bin/modules.ps1`              | Ensures required PS modules (current-user scope).                  |
| `bin/fonts.ps1`                | Cascadia Code Nerd Font installer (idempotent).                    |
| `bin/link.ps1`                 | Creates symlinks for all `.config` entries.                        |
| `bin/profile-setup.ps1`        | Installs PowerShell profile stubs.                                 |
| `bin/self-test.ps1`            | Post-setup validation (symlink, packages, font, modules, profile). |
| `bin/audit.ps1`                | Drift detection vs. manifest (JSON or table output).               |
| `bin/sync.ps1`                 | Re-downloads fresh ZIP & relinks (lightweight update).             |
| `bin/revert.ps1`               | Selective or full cleanup (`-All`, supports `-WhatIf`).            |
| `bin/_common.ps1`              | Shared logging & helpers.                                          |
| `packages/windows-winget.json` | Canonical package ID list.                                         |
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

Selective (links + fonts only):

```powershell
.\bin\revert.ps1 -RemoveLinks -RemoveFonts
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

## License

See [`LICENSE`](./LICENSE) for full text.
