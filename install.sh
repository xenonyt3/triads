#!/usr/bin/env bash
# Installs the risk-router agents into the global OpenCode config.
# Copies agents/*.md to ~/.config/opencode/agents/. Existing files with the
# same name are backed up first. Nothing else in your OpenCode config is touched.
set -euo pipefail

src="$(cd "$(dirname "$0")" && pwd)/agents"
dest="${HOME}/.config/opencode/agents"
stamp="$(date +%Y%m%d-%H%M%S)"

[ -d "$src" ] || { echo "agents folder not found: $src" >&2; exit 1; }
mkdir -p "$dest"

for f in "$src"/*.md; do
  target="$dest/$(basename "$f")"
  if [ -e "$target" ]; then
    cp "$target" "$target.bak-$stamp"
    echo "backup  $target.bak-$stamp"
  fi
  cp "$f" "$target"
  echo "install $target"
done

if command -v opencode >/dev/null 2>&1; then
  ids="$(opencode debug agents 2>/dev/null)"
  for name in orchestrator high-class low-class; do
    if printf '%s' "$ids" | grep -q "\"id\": *\"$name\""; then
      echo "ok      agent '$name' loaded"
    else
      echo "WARNING: agent '$name' not loaded; check 'opencode debug agents'" >&2
    fi
  done
else
  echo "WARNING: opencode not found on PATH; skipped load check" >&2
fi
