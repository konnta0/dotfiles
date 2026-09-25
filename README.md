# dotfiles

Personal configuration files. Portability is not guaranteed across all environments.

## Quick install

```bash
git clone https://github.com/konnta0/dotfiles ~/dotfiles
cd ~/dotfiles
bash install.sh
```

`install.sh` creates symlinks for:

| Source | Destination |
|---|---|
| `.zshrc` | `~/.zshrc` |
| `.config/starship.toml` | `~/.config/starship.toml` |
| `.config/herdr/config.toml` | `~/.config/herdr/config.toml` |
| `glazewm/config.yaml` | `~/.glzr/glazewm/config.yaml` |
| `glazewm/grid.ps1` | `~/.glzr/glazewm/grid.ps1` |
| `glazewm/grid-config.json` | `~/.glzr/glazewm/grid-config.json` |
| `lazygit/config.yml` | `~/Library/Application Support/jesseduffield/lazygit/config.yml` |
| `cursor/rules/*.mdc` | `~/.cursor/rules/*.mdc` |
| `cursor/skills/` | `~/.cursor/skills` |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |

Re-running `install.sh` is safe (idempotent).

## Terminal workspace

[Herdr](https://herdr.dev/) is used instead of tmux. Install Herdr and fzf before
running the dotfiles installer:

```bash
# macOS (Homebrew)
brew install herdr fzf

# Linux / macOS (official Herdr installer)
curl -fsSL https://herdr.dev/install.sh | sh
```

On Windows, use Herdr's native installer and fzf release package, or use the
Linux instructions from WSL. The shell configuration in this repository is for
zsh, so native PowerShell setup is intentionally not managed here.

Run `herdr` (or the `hr` alias) in a project directory. The tracked config keeps
`Ctrl-b` as the prefix, `Ctrl-b v` / `Ctrl-b -` for pane splits, mouse support,
the Solarized theme, and the existing purple accent. `fzf` runs directly rather
than through the tmux-only `fzf-tmux` wrapper.

For agent-aware status and session restore, install the integrations you use:

```bash
herdr integration install codex
herdr integration install claude
```

---

## AI agent configuration

Skills are defined once in `cursor/skills/` and shared across agents:

```
cursor/skills/
├── plan-review-cycle/   # plan → self-review → implement → self-review → fix
├── dotnet-csharp/       # async/await, DI, xUnit, NuGet patterns
├── unity-dev/           # MonoBehaviour, GC avoidance, UniTask, UniCli
├── terraform-iac/       # module layout, plan-before-apply, remote state
└── cloud-infra/         # AWS / GCP IAM, VPC, secrets, security checklist
```

### Cursor

Skills and rules are symlinked automatically by `install.sh`. No additional setup needed.

Cursor rules in `cursor/rules/`:
- `csharp-style.mdc` — C# visibility, XML docs, static lambdas
- `git-main-direct.mdc` — allow direct commits to main
- `terraform-style.mdc` — Terraform file layout and naming

### Claude Code

`install.sh` symlinks `claude/CLAUDE.md` → `~/.claude/CLAUDE.md`.

Skills are loaded via the `--plugin-dir` alias added to `.zshrc`:

```zsh
alias claude="claude --plugin-dir $DOTFILES/claude/plugins"
```

`claude/plugins/skills` is a symlink to `cursor/skills/`, so both agents share the same skill files.

### GitHub Copilot

Copy the template to each project:

```bash
mkdir -p .github
cp ~/dotfiles/copilot/copilot-instructions.md .github/copilot-instructions.md
```

---

## Adding new skills

1. Create `cursor/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`).
2. Both Cursor and Claude Code pick it up automatically (via symlink / `--plugin-dir`).
3. Add it to `copilot/copilot-instructions.md` if relevant for project-level Copilot instructions.

---

## zprezto

### require
https://github.com/sorin-ionescu/prezto

Check and run **Installation**, then:

```bash
cp -f .zprezto/modules/prompt/functions/prompt_sorin_setup ~/.zprezto/modules/prompt/functions/prompt_sorin_setup
```

Change `.zpreztorc`:

```diff
@@ -38,7 +38,11 @@ zstyle ':prezto:load' pmodule \
   'spectrum' \
   'utility' \
   'completion' \
-  'prompt'
+  'prompt' \
+  'git' \
+  'syntax-highlighting' \
+  'history-substring-search' \
+  'autosuggestions'
```

## zinit + starship

```shell
bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
source ~/.zshrc
zinit self-update
```

## VisualStudio Code

[GruvBox Theme](https://marketplace.visualstudio.com/items?itemName=jdinhlife.gruvbox)

## Rider

[GruvBox Theme](https://plugins.jetbrains.com/plugin/12310-gruvbox-theme)

## GlazeWM (macOS)

Install GlazeWM and PowerShell 7, then link the tracked configuration:

```shell
brew install --cask glzr-io/tap/glazewm powershell
bash install.sh
```

Grant GlazeWM access in **System Settings → Privacy & Security →
Accessibility**, then restart it. Subsequent config changes can be applied with
`Option+Shift+R` (`Alt+Shift+R` in the YAML notation).

Custom GlazeWM shortcuts in this repository:

| Shortcut | Action |
|---|---|
| `Option+B` | Set horizontal tiling direction |
| `Option+Shift+B` | Set vertical tiling direction |
| `Option+G` | Center the focused app at 80% width and height |
| `Option+Shift+G` | Enable the automatic square grid for this workspace |
| `Option+Control+G` | Disable the grid and restore GlazeWM tiling |
| `Option+Enter` | Open macOS Terminal |

The PowerShell 7 grid controller runs automatically with GlazeWM on both
Windows and macOS. Every workspace is grid-enabled by default. It reacts when
windows are opened, closed, or moved, when a workspace changes, and when
monitors are added, removed, or resized. Each visible workspace on each monitor
is laid out independently. Up to eight windows use a 4x2 landscape grid or a
2x4 portrait grid; larger sets choose the square-cell arrangement that makes
best use of the workspace. Unused space is centered around the grid.

After requesting the target size, the controller reads back the size each app
actually accepted. It then uses variable column widths and row heights to avoid
overlap even when applications have different minimum sizes. If no arrangement
can fit, it chooses the one with the least overflow and records that fact in the
log.

Windows already made floating by a matching GlazeWM `window_rules` entry are
left alone. For an explicit cross-platform exclusion, add a rule to
`glazewm/grid-config.json` using `processNameRegex`, `titleRegex`, and/or
`classNameRegex`. Matching windows are made floating but are never resized or
repositioned by the grid controller. System Settings is excluded by default.
Grid-managed windows are converted to floating only so the controller can
position them precisely.

Ensure `pwsh` is available on `PATH`; the config intentionally uses no
OS-specific PowerShell path. On Windows, install GlazeWM and PowerShell 7, then
place `grid.ps1` beside `%USERPROFILE%/.glzr/glazewm/config.yaml`. Runtime state
and logs are written to `~/.glzr/glazewm/grid-state.json` and
`~/.glzr/glazewm/grid-controller.log` and are not tracked by this repository.

The outer gap is 20px on every edge; no separate status-bar process is needed.
