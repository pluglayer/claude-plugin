#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
target="${PLUGLAYER_INSTALL_TARGET:-${1:-}}"
label="${PLUGLAYER_INSTALL_LABEL:-PlugLayer plugin}"
version="${PLUGLAYER_PLUGIN_VERSION:-unknown}"
environment_id="${PLUGLAYER_INSTALL_ENVIRONMENT:-local}"
archive_sha256="${PLUGLAYER_ARCHIVE_SHA256:-}"
oauth_url="${PLUGLAYER_OAUTH_URL:-}"
setup_prompt="${PLUGLAYER_SETUP_PROMPT:-Connect PlugLayer with OAuth in your browser.}"
installed_url="${PLUGLAYER_INSTALLED_URL:-}"
failure_url="${PLUGLAYER_INSTALL_FAILURE_URL:-}"
cli_guide="${PLUGLAYER_CLI_GUIDE:-}"
cli_installer="${PLUGLAYER_CLI_INSTALLER:-}"
archive_b64_path="${PLUGLAYER_ARCHIVE_B64_PATH:-}"
# Values and the release archive are supplied by the backend, never credentials.
export PATH="${HOME}/.local/bin:${HOME}/.cursor/bin:${HOME}/.antigravity/bin:${PATH}"
work="$(mktemp -d "${TMPDIR:-/tmp}/pluglayer-oauth-install.XXXXXX")"
cleanup() { rm -rf "$work"; }
report_failure() { [ -n "$failure_url" ] || return 0; curl -fsS --max-time 10 -X POST "$failure_url" >/dev/null 2>&1 || true; }
trap cleanup EXIT
trap report_failure ERR
say() { printf '\n%s\n' "$*"; }
fail() { say "$*" >&2; report_failure; exit 1; }
confirm() {
  local answer
  if ! [ -r /dev/tty ] || ! [ -w /dev/tty ]; then
    fail "Open an interactive terminal and run the same command again."
  fi
  printf '%s [y/N] ' "$1" > /dev/tty
  IFS= read -r answer < /dev/tty
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
open_url() {
  if command -v open >/dev/null; then open "$1" || true
  elif command -v xdg-open >/dev/null; then xdg-open "$1" || true; fi
  say "$1"
}
find_cli() {
  cli=""
  case "$target" in
    codex)
      cli="$(command -v codex || true)"
      if [ -z "$cli" ]; then
        for path in /Applications/Codex.app/Contents/Resources/codex /Applications/ChatGPT.app/Contents/Resources/codex; do
          if [ -x "$path" ]; then cli="$path"; break; fi
        done
      fi ;;
    claude-code) cli="$(command -v claude || true)" ;;
    cursor) cli="$(command -v agent || command -v cursor-agent || true)" ;;
    antigravity) cli="$(command -v agy || true)" ;;
  esac
}
say "1/4 · Checking $label requirements"
command -v curl >/dev/null || fail 'curl is required. Install it using your OS package manager, then retry.'
command -v tar >/dev/null || fail 'tar is required. Install it using your OS package manager, then retry.'
find_cli
if [ -z "$cli" ]; then
  say "$label CLI is missing. Only the native agent is needed; PlugLayer uses hosted MCP."
  if ! confirm "Install the official $label CLI now?"; then
    open_url "$cli_guide"
    fail "Install $label from the guide, then rerun this command (or generate a new link after expiry)."
  fi
  if [ -z "$cli_installer" ]; then
    open_url "$cli_guide"
    fail "Follow the official $label installer, then rerun this command."
  fi
  curl -fsSL --retry 2 "$cli_installer" -o "$work/agent-install.sh"
  bash "$work/agent-install.sh"
  hash -r
  find_cli
fi
[ -n "$cli" ] || fail "The CLI is not on PATH yet. Open a new terminal, then run this command again."
"$cli" --help >/dev/null || fail "$label could not start. Follow $cli_guide and retry."
if [ "$target" != cursor ]; then
  "$cli" plugin --help >/dev/null || fail "Update $label to a version with plugin support, then retry."
fi
say "2/4 · Preparing complete PlugLayer $version package"
source="${PLUGLAYER_PLUGIN_SOURCE_DIR:-}"
[ -d "$source" ] || fail 'Use a fresh Direct install command from the PlugLayer portal.'
install_root="${HOME}/.pluglayer/plugin-packages/${target}/${version}-${environment_id}"
mkdir -p "$(dirname "$install_root")"
# Refuse to replace an edited source. Other releases and user config are retained.
if [ -e "$install_root" ]; then
  diff -qr "$source" "$install_root" >/dev/null || fail "An existing package was edited: $install_root. Preserve it and use the agent prompt to resolve the conflict."
else
  cp -R "$source" "$install_root"
fi
say "3/4 · Registering skills, agents and hosted MCP in $label"
case "$target" in
  codex)
    marketplace="${HOME}/.pluglayer/marketplaces/codex-${environment_id}"
    mkdir -p "$marketplace/.agents/plugins" "$marketplace/plugins"
    if [ -L "$marketplace/plugins/pluglayer-codex-plugin" ]; then rm "$marketplace/plugins/pluglayer-codex-plugin"
    elif [ -e "$marketplace/plugins/pluglayer-codex-plugin" ]; then fail "Unmanaged marketplace path exists: $marketplace/plugins/pluglayer-codex-plugin"; fi
    ln -s "$install_root" "$marketplace/plugins/pluglayer-codex-plugin"
    printf '{"name":"pluglayer-direct-%s","plugins":[{"name":"pluglayer-codex-plugin","source":{"source":"local","path":"./plugins/pluglayer-codex-plugin"},"policy":{"installation":"AVAILABLE","authentication":"ON_INSTALL"},"category":"Developer Tools"}]}\n' "$environment_id" > "$marketplace/.agents/plugins/marketplace.json"
    "$cli" plugin marketplace add "$marketplace"
    "$cli" plugin add "pluglayer-codex-plugin@pluglayer-direct-${environment_id}"
    "$cli" plugin list
    ;;
  claude-code)
    marketplace="${HOME}/.pluglayer/marketplaces/claude-${environment_id}"
    mkdir -p "$marketplace/.claude-plugin" "$marketplace/plugins"
    if [ -L "$marketplace/plugins/pluglayer" ]; then rm "$marketplace/plugins/pluglayer"
    elif [ -e "$marketplace/plugins/pluglayer" ]; then fail "Unmanaged marketplace path exists: $marketplace/plugins/pluglayer"; fi
    ln -s "$install_root" "$marketplace/plugins/pluglayer"
    printf '{"name":"pluglayer-direct-%s","owner":{"name":"PlugLayer"},"plugins":[{"name":"pluglayer","source":"./plugins/pluglayer","version":"%s"}]}\n' "$environment_id" "$version" > "$marketplace/.claude-plugin/marketplace.json"
    "$cli" plugin marketplace add "$marketplace"
    "$cli" plugin install "pluglayer@pluglayer-direct-${environment_id}" --scope user
    "$cli" plugin list
    ;;
  cursor)
    dest="${HOME}/.cursor/plugins/local/pluglayer-cursor-plugin"
    managed="${HOME}/.pluglayer/plugin-state/cursor-${environment_id}"
    if [ -e "$dest" ]; then
      if ! diff -qr "$dest" "$install_root" >/dev/null; then
        [ -d "$managed" ] && diff -qr "$dest" "$managed" >/dev/null || fail "Preserving user-edited Cursor plugin: $dest. Resolve it through the prompt option."
        rm -rf "$dest"
      fi
    fi
    mkdir -p "$(dirname "$dest")" "$(dirname "$managed")"
    if ! [ -e "$dest" ]; then cp -R "$install_root" "$dest"; fi
    if [ -e "$managed" ]; then rm -rf "$managed"; fi
    cp -R "$install_root" "$managed"
    say 'Cursor loads the complete local plugin. Reload any open Cursor window.'
    ;;
  antigravity)
    "$cli" plugin install "$install_root"
    "$cli" plugin list
    ;;
esac
# This callback reports files/registration only, never OAuth readiness.
curl -fsS --max-time 10 -X POST "$installed_url" >/dev/null || say 'Package installed; portal status could not refresh.'
trap - ERR
say "4/4 · Opening $label to connect PlugLayer with browser OAuth"
say 'Keep this terminal and the browser open. Approve access when your agent asks.'
[ -n "$oauth_url" ] && open_url "$oauth_url"
say 'The agent verifies your account and projects before reporting ready.'
if ! [ -r /dev/tty ] || ! [ -w /dev/tty ]; then
  say "Open $label and send this setup request: $setup_prompt"
  exit 0
fi
# Keep host approvals enabled. The host owns browser callback and token refresh.
case "$target" in
  antigravity) "$cli" --prompt-interactive "$setup_prompt" < /dev/tty ;;
  *) "$cli" "$setup_prompt" < /dev/tty ;;
esac
