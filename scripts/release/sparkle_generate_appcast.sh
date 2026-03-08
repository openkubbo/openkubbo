#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/release/_sparkle_tools.sh
source "${SCRIPT_DIR}/_sparkle_tools.sh"

ARCHIVES_DIR="${1:-}"
DOWNLOAD_URL_PREFIX="${2:-${SPARKLE_DOWNLOAD_URL_PREFIX:-}}"
RELEASE_NOTES_URL_PREFIX="${3:-${SPARKLE_RELEASE_NOTES_URL_PREFIX:-}}"
ACCOUNT_NAME="${SPARKLE_ACCOUNT_NAME:-openkubbo}"
PRODUCT_LINK_URL="${SPARKLE_PRODUCT_LINK_URL:-https://openkubbo.com}"

if [[ -z "${ARCHIVES_DIR}" ]]; then
    echo "Usage: $(basename "$0") <archives-dir> [download-url-prefix] [release-notes-url-prefix]" >&2
    exit 1
fi

if [[ ! -d "${ARCHIVES_DIR}" ]]; then
    echo "Archives directory does not exist: ${ARCHIVES_DIR}" >&2
    exit 1
fi

if [[ -z "${DOWNLOAD_URL_PREFIX}" ]]; then
    echo "A download URL prefix is required. Pass it as the second argument or set SPARKLE_DOWNLOAD_URL_PREFIX." >&2
    exit 1
fi

resolve_sparkle_tools

command=(
    "${SPARKLE_BIN_DIR}/generate_appcast"
    --account "${ACCOUNT_NAME}"
    --download-url-prefix "${DOWNLOAD_URL_PREFIX}"
    --link "${PRODUCT_LINK_URL}"
)

if [[ -n "${RELEASE_NOTES_URL_PREFIX}" ]]; then
    command+=(--release-notes-url-prefix "${RELEASE_NOTES_URL_PREFIX}")
fi

command+=("${ARCHIVES_DIR}")

"${command[@]}"

echo "Generated appcast in ${ARCHIVES_DIR}"
