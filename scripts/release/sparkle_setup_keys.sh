#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/release/_sparkle_tools.sh
source "${SCRIPT_DIR}/_sparkle_tools.sh"

ACCOUNT_NAME="${SPARKLE_ACCOUNT_NAME:-openkubbo}"

resolve_sparkle_tools

"${SPARKLE_BIN_DIR}/generate_keys" --account "${ACCOUNT_NAME}"

public_key="$("${SPARKLE_BIN_DIR}/generate_keys" --account "${ACCOUNT_NAME}" -p | tr -d '\r\n')"

if [[ -z "${public_key}" ]]; then
    echo "Sparkle public key was empty after generate_keys." >&2
    exit 1
fi

"${SCRIPT_DIR}/sparkle_set_public_key.sh" "${public_key}"

cat <<EOF
Sparkle key setup complete.
Account: ${ACCOUNT_NAME}
Public key: ${public_key}

The public key has been written into the Xcode project build settings.
Commit the project file if you want this public key versioned in git.
EOF
