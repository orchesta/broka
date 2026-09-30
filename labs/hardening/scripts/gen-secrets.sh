#!/usr/bin/env bash
# Fills the four required secrets in install/.env (created from .env.example) and keeps any already set.
set -euo pipefail

install_dir="$(cd "$(dirname "$0")/../../../install" && pwd)"
env_file="${1:-$install_dir/.env}"

[ -f "$env_file" ] || cp "$install_dir/.env.example" "$env_file"
chmod 600 "$env_file"

fill() {
  local name="$1" value tmp
  if grep -Eq "^$name=[^[:space:]]" "$env_file"; then
    echo "$name: kept"
    return
  fi
  value="$(openssl rand "${@:2}" | tr -d '\n')"
  tmp="$(mktemp)"
  if grep -Eq "^$name=" "$env_file"; then
    awk -v n="$name" -v v="$value" '$0 ~ "^" n "=[[:space:]]*$" { print n "=" v; next } { print }' "$env_file" > "$tmp"
  else
    cat "$env_file" > "$tmp"
    echo "$name=$value" >> "$tmp"
  fi
  cat "$tmp" > "$env_file"
  rm -f "$tmp"
  echo "$name: generated"
}

fill POSTGRES_PASSWORD -base64 24
fill BROKA_JWT_SECRET -base64 48
fill BROKA_KEK -base64 32
fill BROKA_SERVICE_TOKEN -hex 32

echo "Back up $env_file with the database: the secrets cannot be recovered."
