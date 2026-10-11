#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PLUGLAYER_INSTALL_TARGET="claude-code"
export PLUGLAYER_PLUGIN_SOURCE_DIR="${SCRIPT_DIR}"
if [ -f "${SCRIPT_DIR}/install-common.sh" ]; then
  exec bash "${SCRIPT_DIR}/install-common.sh"
fi
printf '%s\n' 'Use the expiring Direct install command from the PlugLayer portal.' >&2
exit 1
