#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPARKLE_TOOLS_ROOT="${PROJECT_ROOT}/.sparkle-tools"
SPARKLE_SOURCE_PACKAGES_DIR="${SPARKLE_TOOLS_ROOT}/source-packages"
SPARKLE_PACKAGE_CACHE_DIR="${SPARKLE_TOOLS_ROOT}/package-cache"
SPARKLE_BIN_DIR="${SPARKLE_SOURCE_PACKAGES_DIR}/artifacts/sparkle/Sparkle/bin"

resolve_sparkle_tools() {
    mkdir -p "${SPARKLE_SOURCE_PACKAGES_DIR}" "${SPARKLE_PACKAGE_CACHE_DIR}"

    xcodebuild \
        -project "${PROJECT_ROOT}/OpenKubbo.xcodeproj" \
        -scheme OpenKubbo \
        -resolvePackageDependencies \
        -clonedSourcePackagesDirPath "${SPARKLE_SOURCE_PACKAGES_DIR}" \
        -packageCachePath "${SPARKLE_PACKAGE_CACHE_DIR}" \
        -onlyUsePackageVersionsFromResolvedFile \
        >/dev/null

    if [[ ! -x "${SPARKLE_BIN_DIR}/generate_keys" ]]; then
        echo "Unable to locate Sparkle tools in ${SPARKLE_BIN_DIR}" >&2
        exit 1
    fi
}
