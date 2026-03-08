#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_FILE="${PROJECT_ROOT}/OpenKubbo.xcodeproj/project.pbxproj"

PUBLIC_KEY="${1:-}"

if [[ -z "${PUBLIC_KEY}" ]]; then
    echo "Usage: $(basename "$0") <sparkle-public-key>" >&2
    exit 1
fi

if [[ ! -f "${PROJECT_FILE}" ]]; then
    echo "Could not find ${PROJECT_FILE}" >&2
    exit 1
fi

escaped_public_key="${PUBLIC_KEY//\\/\\\\}"
escaped_public_key="${escaped_public_key//\"/\\\"}"

perl -0pi -e 's/SPARKLE_PUBLIC_ED_KEY = ".*?";/SPARKLE_PUBLIC_ED_KEY = "'"${escaped_public_key}"'";/g' "${PROJECT_FILE}"

echo "Updated SPARKLE_PUBLIC_ED_KEY in ${PROJECT_FILE}"
