#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

info() { printf "  \033[0;34m•\033[0m %s\n" "$1"; }
ok()   { printf "  \033[0;32m✓\033[0m %s\n" "$1"; }
skip() { printf "  \033[0;33m–\033[0m %s (already linked)\n" "$1"; }

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    skip "$dst"
  else
    ln -sf "$src" "$dst"
    ok "$dst"
  fi
}

echo ""
echo "=== dotfiles install ($(basename "$DOTFILES")) ==="
echo ""

# ── Home dotfiles ─────────────────────────────────────────────
echo "[home]"
link "$DOTFILES/.zshrc"               "$HOME/.zshrc"
link "$DOTFILES/.tmux.conf"           "$HOME/.tmux.conf"
link "$DOTFILES/.config/starship.toml" "$HOME/.config/starship.toml"

# lazygit (macOS path)
LAZYGIT_CFG="$HOME/Library/Application Support/jesseduffield/lazygit"
mkdir -p "$LAZYGIT_CFG"
link "$DOTFILES/lazygit/config.yml"   "$LAZYGIT_CFG/config.yml"

# ── Cursor ────────────────────────────────────────────────────
echo ""
echo "[cursor]"
mkdir -p "$HOME/.cursor/rules"
for rule in "$DOTFILES/cursor/rules/"*.mdc; do
  [ -f "$rule" ] && link "$rule" "$HOME/.cursor/rules/$(basename "$rule")"
done
link "$DOTFILES/cursor/skills" "$HOME/.cursor/skills"

# ── Claude Code ───────────────────────────────────────────────
echo ""
echo "[claude]"
link "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# ── ~/.zshrc.local ────────────────────────────────────────────
echo ""
echo "[zshrc.local]"
LOCAL="$HOME/.zshrc.local"

managed_start="# BEGIN dotfiles-managed"
managed_end="# END dotfiles-managed"

managed_block="${managed_start}
export DOTFILES=\"${DOTFILES}\"
alias claude=\"claude --plugin-dir \$DOTFILES/claude/plugins\"
${managed_end}"

if [ -f "$LOCAL" ]; then
  tmp=$(mktemp)
  awk -v s="$managed_start" -v e="$managed_end" '$0==s{skip=1} skip{if($0==e){skip=0}; next} 1' "$LOCAL" > "$tmp"
  cat "$tmp" > "$LOCAL"
  rm "$tmp"
  printf '\n%s\n' "$managed_block" >> "$LOCAL"
else
  printf '%s\n' "$managed_block" > "$LOCAL"
fi
ok "$LOCAL (DOTFILES=$DOTFILES)"

echo ""
echo "Done. Restart your shell or: source ~/.zshrc"
