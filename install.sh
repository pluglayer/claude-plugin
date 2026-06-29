#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]-}"
SCRIPT_DIR=""
if [ -n "${SCRIPT_PATH}" ] && [ -e "${SCRIPT_PATH}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
fi
COMMON_URL="${PLUGLAYER_INSTALL_COMMON_URL:-https://raw.githubusercontent.com/pluglayer/claude-plugin/main/install-common.sh}"
ARCHIVE_URL="${PLUGLAYER_REPO_ARCHIVE_URL:-https://github.com/pluglayer/claude-plugin/archive/refs/heads/main.tar.gz}"

if [ -n "${SCRIPT_DIR}" ] && [ -f "${SCRIPT_DIR}/install-common.sh" ]; then
  PLUGLAYER_INSTALL_TARGET=claude \
  PLUGLAYER_PLUGIN_SOURCE_DIR="${SCRIPT_DIR}" \
  PLUGLAYER_PLUGIN_SOURCE_RELATIVE_PATH="." \
  PLUGLAYER_REPO_ARCHIVE_URL="${ARCHIVE_URL}" \
  bash "${SCRIPT_DIR}/install-common.sh" "$@"
  exit 0
fi

TMP_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/pluglayer-claude-install-common.XXXXXX")"
trap 'rm -f "${TMP_SCRIPT}"' EXIT
curl -fsSL "${COMMON_URL}" -o "${TMP_SCRIPT}"
PLUGLAYER_INSTALL_TARGET=claude \
PLUGLAYER_PLUGIN_SOURCE_RELATIVE_PATH="." \
PLUGLAYER_REPO_ARCHIVE_URL="${ARCHIVE_URL}" \
bash "${TMP_SCRIPT}" "$@"
