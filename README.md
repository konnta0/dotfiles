# dotfiles

Personal configuration files. Portability is not guaranteed across all environments.

## Quick install

```bash
git clone https://github.com/konnta0/dotfiles ~/ghq/github.com/konnta0/dotfiles
cd ~/ghq/github.com/konnta0/dotfiles
bash install.sh
```

`install.sh` creates symlinks for:

| Source | Destination |
|---|---|
| `.zshrc` | `~/.zshrc` |
| `.tmux.conf` | `~/.tmux.conf` |
| `.config/starship.toml` | `~/.config/starship.toml` |
| `lazygit/config.yml` | `~/Library/Application Support/jesseduffield/lazygit/config.yml` |
| `cursor/rules/*.mdc` | `~/.cursor/rules/*.mdc` |
| `cursor/skills/` | `~/.cursor/skills` |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |

Re-running `install.sh` is safe (idempotent).

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
cp ~/ghq/github.com/konnta0/dotfiles/copilot/copilot-instructions.md .github/copilot-instructions.md
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

## For Windows

WIP — Install WSL first.
