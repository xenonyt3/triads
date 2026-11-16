#!/usr/bin/env bash
main() {
set -euo pipefail

names=(helios gaia selene)
dest="${OPENCODE_CONFIG_DIR:-${HOME}/.config/opencode}/agents"
temp_dir=''
trap 'if [[ -n "$temp_dir" ]]; then rm -rf -- "$temp_dir"; fi' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --uninstall ) ]]; then
  fail 'usage: install.sh [--uninstall]'
fi
if [[ "${1:-}" == --uninstall ]]; then
  for name in "${names[@]}"; do
    target="$dest/$name.md"
    newest=''
    for backup in "$target".bak-*; do
      [[ -f "$backup" && "$backup" =~ \.bak-[0-9]{8}-[0-9]{6}$ ]] || continue
      if [[ -z "$newest" || "$backup" > "$newest" ]]; then newest="$backup"; fi
    done
    if [[ -e "$target" || -L "$target" ]]; then
      rm -- "$target"
      printf 'remove  %s\n' "$target"
    fi
    if [[ -n "$newest" ]]; then
      mv -- "$newest" "$target"
      printf 'restore %s -> %s\n' "$newest" "$target"
    fi
  done
  exit 0
fi
src=''
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/agents"
fi
local_source=true
for name in "${names[@]}"; do
  if [[ -z "$src" || ! -f "$src/$name.md" ]]; then local_source=false; fi
done
if [[ "$local_source" == false ]]; then
  temp_dir="$(mktemp -d)"
  src="$temp_dir"
  for name in "${names[@]}"; do
    url="https://raw.githubusercontent.com/xenonyt3/triads/main/agents/$name.md"
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "$url" > "$src/$name.md" || fail "download $name.md failed"
    elif command -v wget >/dev/null 2>&1; then
      wget -qO- "$url" > "$src/$name.md" || fail "download $name.md failed"
    else
      fail "download $name.md failed: curl or wget required"
    fi
  done
fi
for name in "${names[@]}"; do
  first=''
  IFS= read -r first < "$src/$name.md" || true
  [[ "${first%$'\r'}" == --- ]] || fail "invalid $name.md: first line must be exactly --- (not HTML or empty)"
done
mkdir -p -- "$dest"
for old in orchestrator.md high-class.md low-class.md; do
  if [[ -e "$dest/$old" ]]; then warn "$old is from an older version; remove it manually if no longer needed"; fi
done
for name in "${names[@]}"; do
  target="$dest/$name.md"
  if [[ -e "$target" ]]; then
    if cmp -s -- "$src/$name.md" "$target"; then
      printf 'same    %s\n' "$target"
      continue
    fi
    backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
    # Wait for a fresh stamp rather than overwrite a backup from this second.
    while [[ -e "$backup" || -L "$backup" ]]; do
      sleep 1
      backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
    done
    cp -- "$target" "$backup"
    printf 'backup  %s\n' "$backup"
  fi
  cp -- "$src/$name.md" "$target"
  printf 'install %s\n' "$target"
done
checks() {
  local help_text output ids models provider name
  local warned=$'\n'
  local flags=()
  if ! command -v opencode >/dev/null 2>&1; then
    warn 'opencode not found on PATH; skipped checks'
    return 0
  fi
  help_text="$(opencode --help </dev/null 2>&1)" || warn 'could not inspect opencode --help'
  if [[ "$help_text" == *--standalone* ]]; then flags=(--standalone); fi
  if output="$(opencode ${flags[@]+"${flags[@]}"} debug agents </dev/null 2>&1)"; then
    # JSON parsing is optional, not a new installation dependency.
    if command -v node >/dev/null 2>&1; then
      if ids="$(printf '%s' "$output" | node -e 'let s="";process.stdin.on("data",c=>s+=c);process.stdin.on("end",()=>{try{const a=JSON.parse(s);if(!Array.isArray(a))throw Error("expected array");for(const x of a)console.log(x.id ?? x.name)}catch(e){process.exitCode=1}})' 2>/dev/null)"; then
        for name in "${names[@]}"; do
          if printf '%s\n' "$ids" | grep -Fx "$name" >/dev/null; then printf "ok      agent '%s' loaded\n" "$name"
          else warn "agent '$name' not loaded; check 'opencode debug agents'"; fi
        done
      else warn 'agent load check returned invalid JSON'; fi
    else warn 'no JSON parser (node) available; skipped agent load check'; fi
  else warn 'agent load check failed'; fi
  if models="$(opencode ${flags[@]+"${flags[@]}"} models </dev/null 2>&1)"; then
    for name in "${names[@]}"; do
      provider="$(sed -n 's|^model:[[:space:]]*\([^/[:space:]]*\)/.*|\1|p' "$dest/$name.md")" || { warn "cannot read model in $name.md"; continue; }
      if [[ -z "$provider" ]]; then warn "no model provider found in $name.md"
      elif [[ "$models" != *"$provider/"* && "$warned" != *$'\n'"$provider"$'\n'* ]]; then
        warn "provider '$provider' not found in your OpenCode setup; see README \"Choose your models\""
        warned+="$provider"$'\n'
      fi
    done
  else warn 'provider check failed'; fi
  return 0
}
checks || warn 'post-install checks failed'
printf 'done\n'
exit 0
}
main "$@"
