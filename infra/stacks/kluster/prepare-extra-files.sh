#!/usr/bin/env bash
set -euo pipefail

key_file="${TAKINA_SOPS_KEY_FILE:?TAKINA_SOPS_KEY_FILE is required}"
install -D -m 0600 "$key_file" ./var/lib/sops-nix/takina_ed25519
