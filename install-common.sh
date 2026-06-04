#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${PLUGLAYER_INSTALL_TARGET:-}}"
if [ -z "${TARGET}" ]; then
  printf 'Usage: %s <claude|codex|cursor>\n' "${0##*/}" >&2
  exit 1
fi
if [ "${1:-}" = "${TARGET}" ]; then
  shift || true
fi

PLUGLAYER_HOME="${PLUGLAYER_HOME:-${HOME}/.pluglayer}"
BIN_DIR="${HOME}/.local/bin"
STATE_DIR="${PLUGLAYER_HOME}/state"
BUNDLES_DIR="${PLUGLAYER_HOME}/bundles"
CREDENTIALS_FILE="${PLUGLAYER_HOME}/credentials.env"
PORTAL_TOKENS_URL="${PLUGLAYER_PORTAL_TOKENS_URL:-https://portal.pluglayer.com/tokens}"
DEFAULT_API_URL="${PLUGLAYER_API_URL:-https://api.pluglayer.com}"
REPO_ARCHIVE_URL="${PLUGLAYER_REPO_ARCHIVE_URL:-https://github.com/pluglayer/pluglayer/archive/refs/heads/main.tar.gz}"
REPO_ROOT_OVERRIDE="${PLUGLAYER_REPO_ROOT:-}"
PLUGIN_SOURCE_DIR_OVERRIDE="${PLUGLAYER_PLUGIN_SOURCE_DIR:-}"
PLUGIN_SOURCE_RELATIVE_PATH_DEFAULT="${PLUGLAYER_PLUGIN_SOURCE_RELATIVE_PATH:-}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pluglayer-install.XXXXXX")"
STAGED_PLUGIN_DIR="${TMP_ROOT}/plugin"
MANIFEST_RELATIVE_PATH=""
PLUGIN_SOURCE_RELATIVE_PATH=""
PLUGIN_NAME=""
TARGET_LABEL=""
TARGET_COMMAND=""
TARGET_PLUGIN_DIR=""
TARGET_LAUNCHER=""
METADATA_FILE=""
AVAILABLE_VERSION=""
INSTALLED_VERSION=""
INSTALLED_AT=""
SAVED_TOKEN=""
SAVED_API_URL="${DEFAULT_API_URL}"
PLUGLAYER_API_KEY="${PLUGLAYER_API_KEY:-}"
PLUGLAYER_API_URL="${PLUGLAYER_API_URL:-${DEFAULT_API_URL}}"
INITIAL_API_KEY="${PLUGLAYER_API_KEY}"
INITIAL_API_URL="${PLUGLAYER_API_URL}"
MARKETPLACE_FILE="${HOME}/.agents/plugins/marketplace.json"
MARKETPLACE_PLUGIN_DIR="${HOME}/.agents/plugins/plugins"
MARKETPLACE_NAME="personal"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

color() {
  printf '\033[%sm%s\033[0m' "$1" "$2"
}

cyan() {
  color '38;2;2;183;207' "$1"
}

green() {
  color '1;32' "$1"
}

yellow() {
  color '1;33' "$1"
}

red() {
  color '1;31' "$1"
}

muted() {
  color '2' "$1"
}

tty_available() {
  [ -r /dev/tty ] && [ -w /dev/tty ]
}

prompt_print() {
  if tty_available; then
    printf '%s' "$1" > /dev/tty
  else
    printf '%s' "$1" >&2
  fi
}

prompt_println() {
  if tty_available; then
    printf '%s\n' "$1" > /dev/tty
  else
    printf '%s\n' "$1" >&2
  fi
}

headline() {
  printf '\n%s\n' "$(cyan "$1")"
}

step() {
  printf '%s %s\n' "$(cyan "==>")" "$1"
}

success() {
  printf '%s %s\n' "$(green "OK")" "$1"
}

warn() {
  printf '%s %s\n' "$(yellow "WARN")" "$1"
}

die() {
  printf '%s %s\n' "$(red "ERROR")" "$1" >&2
  exit 1
}

print_banner() {
  printf '\n'
  cyan '██████╗ ██╗     ██╗   ██╗ ██████╗ ██╗      █████╗ ██╗   ██╗███████╗██████╗'
  printf '\n'
  cyan '██╔══██╗██║     ██║   ██║██╔════╝ ██║     ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗'
  printf '\n'
  cyan '██████╔╝██║     ██║   ██║██║  ███╗██║     ███████║ ╚████╔╝ █████╗  ██████╔╝'
  printf '\n'
  cyan '██╔═══╝ ██║     ██║   ██║██║   ██║██║     ██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗'
  printf '\n'
  cyan '██║     ███████╗╚██████╔╝╚██████╔╝███████╗██║  ██║   ██║   ███████╗██║  ██║'
  printf '\n'
  cyan '╚═╝     ╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝'
  printf '\n\n'
  printf '%s\n' "$(cyan "PlugLayer for ${TARGET_LABEL}")"
  printf '%s\n\n' "$(muted "Install, update, and keep your PlugLayer plugin ready everywhere.")"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "Missing required command: $1"
  fi
}

ensure_path_line() {
  local shell_rc="$1"
  local line='export PATH="$HOME/.local/bin:$PATH"'
  if [ -f "${shell_rc}" ]; then
    if ! grep -Fq "${line}" "${shell_rc}"; then
      printf '\n%s\n' "${line}" >> "${shell_rc}"
    fi
  else
    printf '%s\n' "${line}" > "${shell_rc}"
  fi
}

ensure_uv() {
  if command -v uvx >/dev/null 2>&1; then
    return
  fi

  step "Installing uv so ${TARGET_LABEL} can run the PlugLayer MCP"
  curl -LsSf https://astral.sh/uv/install.sh | sh

  if [ -f "${HOME}/.cargo/env" ]; then
    # shellcheck disable=SC1090
    . "${HOME}/.cargo/env"
  fi

  command -v uvx >/dev/null 2>&1 || die "uvx is still unavailable after the uv install."
  success "uvx is available"
}

mask_token() {
  local token="$1"
  local length="${#token}"
  if [ "${length}" -le 8 ]; then
    printf '%s' '********'
    return
  fi
  printf '%s...%s' "${token:0:4}" "${token:length-4:4}"
}

read_secret() {
  local prompt="$1"
  local value=""
  prompt_print "${prompt}"
  if tty_available; then
    IFS= read -rs value < /dev/tty
  else
    IFS= read -rs value
  fi
  prompt_print $'\n'
  printf '%s' "${value}"
}

confirm_yes_default() {
  local prompt="$1"
  local answer=""
  prompt_print "${prompt} [Y/n] "
  if tty_available; then
    IFS= read -r answer < /dev/tty
  else
    IFS= read -r answer
  fi
  case "${answer:-Y}" in
    [nN]|[nN][oO]) return 1 ;;
    *) return 0 ;;
  esac
}

menu_choice() {
  local prompt="$1"
  shift
  local option
  local i=1
  prompt_println "${prompt}"
  for option in "$@"; do
    prompt_println "  ${i}. ${option}"
    i=$((i + 1))
  done

  while true; do
    prompt_print 'Choose an option: '
    if tty_available; then
      IFS= read -r option < /dev/tty
    else
      IFS= read -r option
    fi
    case "${option}" in
      ''|*[!0-9]*) ;;
      *)
        if [ "${option}" -ge 1 ] && [ "${option}" -lt "${i}" ]; then
          printf '%s' "${option}"
          return
        fi
        ;;
    esac
    warn "Please enter a number from 1 to $((i - 1))."
  done
}

configure_target() {
  case "${TARGET}" in
    claude)
      TARGET_LABEL="Claude Code"
      PLUGIN_NAME="pluglayer"
      PLUGIN_SOURCE_RELATIVE_PATH="${PLUGIN_SOURCE_RELATIVE_PATH_DEFAULT:-plugins/pluglayer-claude-plugin}"
      MANIFEST_RELATIVE_PATH=".claude-plugin/plugin.json"
      TARGET_COMMAND="claude"
      TARGET_PLUGIN_DIR="${PLUGLAYER_HOME}/plugins/claude/pluglayer"
      TARGET_LAUNCHER="${BIN_DIR}/claude-pluglayer"
      ;;
    codex)
      TARGET_LABEL="Codex"
      PLUGIN_NAME="pluglayer-codex-plugin"
      PLUGIN_SOURCE_RELATIVE_PATH="${PLUGIN_SOURCE_RELATIVE_PATH_DEFAULT:-plugins/pluglayer-codex-plugin}"
      MANIFEST_RELATIVE_PATH=".codex-plugin/plugin.json"
      TARGET_COMMAND="codex"
      TARGET_PLUGIN_DIR="${MARKETPLACE_PLUGIN_DIR}/${PLUGIN_NAME}"
      TARGET_LAUNCHER="${BIN_DIR}/codex-pluglayer"
      ;;
    cursor)
      TARGET_LABEL="Cursor"
      PLUGIN_NAME="pluglayer-cursor-plugin"
      PLUGIN_SOURCE_RELATIVE_PATH="${PLUGIN_SOURCE_RELATIVE_PATH_DEFAULT:-plugins/pluglayer-cursor-plugin}"
      MANIFEST_RELATIVE_PATH=".cursor-plugin/plugin.json"
      TARGET_COMMAND="cursor"
      TARGET_PLUGIN_DIR="${HOME}/.cursor/plugins/local/${PLUGIN_NAME}"
      TARGET_LAUNCHER="${BIN_DIR}/cursor-pluglayer"
      ;;
    *)
      die "Unsupported target '${TARGET}'. Expected claude, codex, or cursor."
      ;;
  esac

  METADATA_FILE="${STATE_DIR}/${TARGET}.env"
}

stage_plugin_bundle() {
  local source_dir=""
  step "Preparing the ${TARGET_LABEL} plugin bundle"

  if [ -n "${PLUGIN_SOURCE_DIR_OVERRIDE}" ] && [ -d "${PLUGIN_SOURCE_DIR_OVERRIDE}" ]; then
    source_dir="${PLUGIN_SOURCE_DIR_OVERRIDE}"
  elif [ -n "${REPO_ROOT_OVERRIDE}" ] && [ -d "${REPO_ROOT_OVERRIDE}/${PLUGIN_SOURCE_RELATIVE_PATH}" ]; then
    source_dir="${REPO_ROOT_OVERRIDE}/${PLUGIN_SOURCE_RELATIVE_PATH}"
  else
    require_cmd curl
    require_cmd tar

    local archive_path="${TMP_ROOT}/pluglayer.tar.gz"
    local extract_dir="${TMP_ROOT}/extract"
    mkdir -p "${extract_dir}"
    curl -fsSL "${REPO_ARCHIVE_URL}" -o "${archive_path}"
    tar -xzf "${archive_path}" -C "${extract_dir}"

    if [ "${PLUGIN_SOURCE_RELATIVE_PATH}" = "." ]; then
      source_dir="$(find "${extract_dir}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    else
      source_dir="$(find "${extract_dir}" -type d -path "*/${PLUGIN_SOURCE_RELATIVE_PATH}" | head -n 1)"
    fi
    [ -n "${source_dir}" ] || die "Could not find ${PLUGIN_SOURCE_RELATIVE_PATH} inside the PlugLayer archive."
  fi

  mkdir -p "${STAGED_PLUGIN_DIR}"
  cp -R "${source_dir}/." "${STAGED_PLUGIN_DIR}/"

  require_cmd python3
  AVAILABLE_VERSION="$(python3 - "${STAGED_PLUGIN_DIR}/${MANIFEST_RELATIVE_PATH}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
print(payload.get("version", "0.0.0"))
PY
)"

  success "Prepared ${TARGET_LABEL} plugin version ${AVAILABLE_VERSION}"
}

load_saved_state() {
  mkdir -p "${PLUGLAYER_HOME}" "${STATE_DIR}" "${BUNDLES_DIR}" "${BIN_DIR}"

  if [ -f "${CREDENTIALS_FILE}" ]; then
    # shellcheck disable=SC1090
    . "${CREDENTIALS_FILE}"
    SAVED_TOKEN="${PLUGLAYER_API_KEY:-}"
    SAVED_API_URL="${PLUGLAYER_API_URL:-${DEFAULT_API_URL}}"
  fi

  PLUGLAYER_API_KEY="${INITIAL_API_KEY}"
  PLUGLAYER_API_URL="${INITIAL_API_URL}"

  if [ -f "${METADATA_FILE}" ]; then
    # shellcheck disable=SC1090
    . "${METADATA_FILE}"
    INSTALLED_VERSION="${PLUGLAYER_PLUGIN_VERSION:-}"
    INSTALLED_AT="${PLUGLAYER_INSTALLED_AT:-}"
  fi
}

write_credentials() {
  mkdir -p "${PLUGLAYER_HOME}"
  {
    printf 'export PLUGLAYER_API_KEY=%q\n' "${PLUGLAYER_API_KEY}"
    printf 'export PLUGLAYER_API_URL=%q\n' "${PLUGLAYER_API_URL}"
  } > "${CREDENTIALS_FILE}"
  chmod 600 "${CREDENTIALS_FILE}"
}

write_metadata() {
  {
    printf 'export PLUGLAYER_TARGET=%q\n' "${TARGET}"
    printf 'export PLUGLAYER_PLUGIN_VERSION=%q\n' "${AVAILABLE_VERSION}"
    printf 'export PLUGLAYER_PLUGIN_DIR=%q\n' "${TARGET_PLUGIN_DIR}"
    printf 'export PLUGLAYER_INSTALLED_AT=%q\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "${METADATA_FILE}"
}

prompt_for_token() {
  printf '%s\n' "$(yellow "Grab a PlugLayer token from ${PORTAL_TOKENS_URL}")"
  PLUGLAYER_API_KEY="$(read_secret 'Paste your PlugLayer token and press Enter: ')"
  [ -n "${PLUGLAYER_API_KEY}" ] || die "A PlugLayer token is required."
  PLUGLAYER_API_URL="${SAVED_API_URL:-${DEFAULT_API_URL}}"
}

resolve_token_for_install() {
  if [ -n "${PLUGLAYER_API_KEY}" ]; then
    return
  fi

  if [ -n "${SAVED_TOKEN}" ]; then
    local masked
    masked="$(mask_token "${SAVED_TOKEN}")"
    if confirm_yes_default "Use the saved token ${masked}?"; then
      PLUGLAYER_API_KEY="${SAVED_TOKEN}"
      PLUGLAYER_API_URL="${SAVED_API_URL:-${DEFAULT_API_URL}}"
      return
    fi
  fi

  prompt_for_token
}

update_token_only() {
  headline "Update token"
  if [ -n "${SAVED_TOKEN}" ]; then
    printf 'Current saved token: %s\n' "$(mask_token "${SAVED_TOKEN}")"
  else
    printf 'No PlugLayer token is saved yet.\n'
  fi
  prompt_for_token
  write_credentials
  success "Saved the PlugLayer token for ${TARGET_LABEL}"
}

write_launcher() {
  local launcher_path="$1"
  local command="$2"
  local plugin_dir="${3:-}"
  local plugin_flag="${4:-}"

  cat > "${launcher_path}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="\${HOME}/.pluglayer/credentials.env"
if [ -f "\${ENV_FILE}" ]; then
  # shellcheck disable=SC1090
  . "\${ENV_FILE}"
fi

exec ${command} ${plugin_flag:+${plugin_flag} "${plugin_dir}"} "\$@"
EOF
  chmod +x "${launcher_path}"
}

remove_existing_install() {
  case "${TARGET}" in
    claude|cursor)
      rm -rf "${TARGET_PLUGIN_DIR}"
      ;;
    codex)
      if [ -f "${MARKETPLACE_FILE}" ]; then
        MARKETPLACE_NAME="$(python3 - "${MARKETPLACE_FILE}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
print(payload.get("name", "personal"))
PY
)"
      fi
      codex plugin remove "${PLUGIN_NAME}@${MARKETPLACE_NAME}" >/dev/null 2>&1 || true
      rm -rf "${TARGET_PLUGIN_DIR}"
      ;;
  esac
}

install_claude() {
  step "Installing PlugLayer into Claude Code"
  require_cmd claude
  ensure_uv

  rm -rf "${TARGET_PLUGIN_DIR}"
  mkdir -p "${TARGET_PLUGIN_DIR}"
  cp -R "${STAGED_PLUGIN_DIR}/." "${TARGET_PLUGIN_DIR}/"
  write_launcher "${TARGET_LAUNCHER}" "claude" "${TARGET_PLUGIN_DIR}" "--plugin-dir"
  success "Claude Code now has PlugLayer at ${TARGET_PLUGIN_DIR}"
}

upsert_codex_marketplace() {
  mkdir -p "${MARKETPLACE_PLUGIN_DIR}"
  rm -rf "${TARGET_PLUGIN_DIR}"
  mkdir -p "${TARGET_PLUGIN_DIR}"
  cp -R "${STAGED_PLUGIN_DIR}/." "${TARGET_PLUGIN_DIR}/"

  MARKETPLACE_NAME="$(python3 - "${MARKETPLACE_FILE}" "${PLUGIN_NAME}" <<'PY'
import json
import os
import sys

marketplace_path, plugin_name = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(marketplace_path), exist_ok=True)

if os.path.exists(marketplace_path):
    with open(marketplace_path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
else:
    payload = {
        "name": "personal",
        "interface": {"displayName": "Personal"},
        "plugins": [],
    }

payload.setdefault("name", "personal")
payload.setdefault("interface", {})
payload["interface"].setdefault("displayName", "Personal")
plugins = payload.setdefault("plugins", [])

entry = {
    "name": plugin_name,
    "source": {
        "source": "local",
        "path": f"./plugins/{plugin_name}",
    },
    "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL",
    },
    "category": "Developer Tools",
}

replaced = False
for index, existing in enumerate(plugins):
    if isinstance(existing, dict) and existing.get("name") == plugin_name:
        plugins[index] = entry
        replaced = True
        break

if not replaced:
    plugins.append(entry)

with open(marketplace_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")

print(payload["name"])
PY
)"
}

install_codex() {
  step "Installing PlugLayer into the Codex personal marketplace"
  require_cmd codex
  ensure_uv
  upsert_codex_marketplace
  codex plugin add "${PLUGIN_NAME}@${MARKETPLACE_NAME}"
  write_launcher "${TARGET_LAUNCHER}" "codex"
  success "Codex now has PlugLayer installed from the ${MARKETPLACE_NAME} marketplace"
}

install_cursor() {
  step "Installing PlugLayer into Cursor"
  require_cmd cursor
  ensure_uv

  rm -rf "${TARGET_PLUGIN_DIR}"
  mkdir -p "${TARGET_PLUGIN_DIR}"
  cp -R "${STAGED_PLUGIN_DIR}/." "${TARGET_PLUGIN_DIR}/"
  write_launcher "${TARGET_LAUNCHER}" "cursor"
  success "Cursor now has PlugLayer at ${TARGET_PLUGIN_DIR}"
}

install_target() {
  resolve_token_for_install
  write_credentials
  remove_existing_install

  case "${TARGET}" in
    claude) install_claude ;;
    codex) install_codex ;;
    cursor) install_cursor ;;
  esac

  ensure_path_line "${HOME}/.zshrc"
  ensure_path_line "${HOME}/.bashrc"
  ensure_path_line "${HOME}/.profile"
  write_metadata
}

post_install_summary() {
  headline "All set"
  printf 'Installed version: %s\n' "${AVAILABLE_VERSION}"
  printf 'Saved token: %s\n' "$(mask_token "${PLUGLAYER_API_KEY}")"
  printf 'Launcher: %s\n' "${TARGET_LAUNCHER}"
  case "${TARGET}" in
    codex)
      printf 'Marketplace: %s\n' "${MARKETPLACE_NAME}"
      printf 'Plugin source: %s\n' "${TARGET_PLUGIN_DIR}"
      ;;
    *)
      printf 'Plugin directory: %s\n' "${TARGET_PLUGIN_DIR}"
      ;;
  esac
}

launch_now() {
  if [ ! -t 0 ] && ! tty_available; then
    return
  fi

  if ! confirm_yes_default "Launch ${TARGET_LABEL} with PlugLayer now?"; then
    return
  fi

  step "Launching ${TARGET_LABEL}"
  exec "${TARGET_LAUNCHER}" "$@"
}

show_status() {
  headline "Status"
  if [ -n "${INSTALLED_VERSION}" ]; then
    printf 'Installed version: %s\n' "${INSTALLED_VERSION}"
  else
    printf 'Installed version: none\n'
  fi
  printf 'Available version: %s\n' "${AVAILABLE_VERSION}"
  if [ -n "${INSTALLED_AT}" ]; then
    printf 'Installed at: %s\n' "${INSTALLED_AT}"
  fi
  if [ -n "${SAVED_TOKEN}" ]; then
    printf 'Saved token: %s\n' "$(mask_token "${SAVED_TOKEN}")"
  else
    printf 'Saved token: none\n'
  fi
  printf '\n'
}

main() {
  configure_target
  print_banner
  stage_plugin_bundle
  load_saved_state
  show_status

  if [ -z "${INSTALLED_VERSION}" ]; then
    install_target
    post_install_summary
    launch_now "$@"
    exit 0
  fi

  local update_label
  if [ "${INSTALLED_VERSION}" != "${AVAILABLE_VERSION}" ]; then
    update_label="Update PlugLayer for ${TARGET_LABEL} to ${AVAILABLE_VERSION}"
  else
    update_label="Reinstall PlugLayer for ${TARGET_LABEL}"
  fi

  local choice
  choice="$(menu_choice "PlugLayer is already installed for ${TARGET_LABEL}." \
    "${update_label}" \
    "Update token" \
    "Exit")"

  case "${choice}" in
    1)
      install_target
      post_install_summary
      launch_now "$@"
      ;;
    2)
      update_token_only
      ;;
    3)
      printf '%s\n' "$(muted "No changes made.")"
      ;;
  esac
}

main "$@"
