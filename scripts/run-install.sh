#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

read -r -s -p "Password for the Codex VM account: " VM_PASSWORD
printf '\n'
read -r -s -p "Repeat password: " VM_PASSWORD_CONFIRM
printf '\n'

if [[ "$VM_PASSWORD" != "$VM_PASSWORD_CONFIRM" ]]; then
    echo "Passwords do not match." >&2
    exit 1
fi

HASH="$(printf '%s' "$VM_PASSWORD" | openssl passwd -6 -stdin)"
unset VM_PASSWORD VM_PASSWORD_CONFIRM

EXTRA_VARS="$(mktemp)"
trap 'rm -f "$EXTRA_VARS"' EXIT
chmod 600 "$EXTRA_VARS"
printf 'codex_password_crypted: "%s"\n' "$HASH" > "$EXTRA_VARS"
unset HASH

ANSIBLE_FORCE_COLOR=1 ansible-playbook \
    -i inventory.ini \
    site.yml \
    --extra-vars "@$EXTRA_VARS" \
    "$@"
