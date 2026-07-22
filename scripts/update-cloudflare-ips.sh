#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target="$repo_root/modules/k3s/system/traefik.nix"
tmp_dir="$(mktemp -d)"

trap 'rm -rf "$tmp_dir"' EXIT

fetch() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$output" "$url"
  else
    printf 'error: curl or wget is required\n' >&2
    exit 1
  fi
}

validate() {
  local file="$1"
  local family="$2"
  local pattern

  if [[ ! -s "$file" ]]; then
    printf 'error: %s is empty\n' "$file" >&2
    exit 1
  fi

  case "$family" in
    4) pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$' ;;
    6) pattern='^[0-9A-Fa-f:]+/[0-9]{1,3}$' ;;
    *)
      printf 'error: unknown IP family %s\n' "$family" >&2
      exit 1
      ;;
  esac

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    if [[ ! "$line" =~ $pattern ]]; then
      printf 'error: invalid IPv%s CIDR: %s\n' "$family" "$line" >&2
      exit 1
    fi
  done <"$file"
}

fetch https://www.cloudflare.com/ips-v4 "$tmp_dir/ips-v4.txt"
fetch https://www.cloudflare.com/ips-v6 "$tmp_dir/ips-v6.txt"

validate "$tmp_dir/ips-v4.txt" 4
validate "$tmp_dir/ips-v6.txt" 6

block="$tmp_dir/cloudflare-rules.nix"
updated="$tmp_dir/traefik.nix"

{
  printf '    # BEGIN CLOUDFLARE SOURCE RANGES\n'
  while IFS= read -r source || [[ -n "$source" ]]; do
    [[ -n "$source" ]] || continue
    printf '    "%s"\n' "$source"
  done <"$tmp_dir/ips-v4.txt"
  while IFS= read -r source || [[ -n "$source" ]]; do
    [[ -n "$source" ]] || continue
    printf '    "%s"\n' "$source"
  done <"$tmp_dir/ips-v6.txt"
  printf '    # END CLOUDFLARE SOURCE RANGES\n'
} >"$block"

awk -v block_file="$block" '
  BEGIN {
    while ((getline line < block_file) > 0) {
      replacement = replacement line ORS
    }
    close(block_file)
  }

  /# BEGIN CLOUDFLARE SOURCE RANGES/ {
    if (seen_begin) {
      print "error: duplicate Cloudflare begin marker" > "/dev/stderr"
      exit 1
    }
    printf "%s", replacement
    seen_begin = 1
    in_block = 1
    next
  }

  /# END CLOUDFLARE SOURCE RANGES/ {
    if (!in_block) {
      print "error: Cloudflare end marker without begin marker" > "/dev/stderr"
      exit 1
    }
    seen_end = 1
    in_block = 0
    next
  }

  !in_block { print }

  END {
    if (!seen_begin || !seen_end || in_block) {
      print "error: Cloudflare marker block not found" > "/dev/stderr"
      exit 1
    }
  }
' "$target" >"$updated"

install -m 0644 "$updated" "$target"

printf 'Updated Cloudflare load balancer source ranges in %s\n' "$target"
