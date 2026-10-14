#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
target="${PLUGLAYER_INSTALL_TARGET:-${1:-}}"
label="${PLUGLAYER_INSTALL_LABEL:-PlugLayer plugin}"
version="${PLUGLAYER_PLUGIN_VERSION:-unknown}"
environment_id="${PLUGLAYER_INSTALL_ENVIRONMENT:-local}"
installed_url="${PLUGLAYER_INSTALLED_URL:-}"
failure_url="${PLUGLAYER_INSTALL_FAILURE_URL:-}"
cli_guide="${PLUGLAYER_CLI_GUIDE:-}"
cli_installer="${PLUGLAYER_CLI_INSTALLER:-}"
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
# Remove only our entry from shared catalogs. Never remove the personal source,
# which may also own private operator or unrelated plugins.
remove_legacy_plugin() {
  local selector="$1"
  if ! "$cli" plugin remove "$selector" < /dev/null > "$work/remove.log" 2>&1; then
    if ! grep -Eiq 'not installed|not found|could not find|no plugin' "$work/remove.log"; then
      fail "Could not migrate the existing PlugLayer registration: $selector. Retry after resolving the native plugin manager error."
    fi
  fi
}
remove_legacy_marketplace() {
  if ! "$cli" plugin marketplace remove "$1" < /dev/null > "$work/remove-marketplace.log" 2>&1; then
    grep -Eiq 'not configured|not found|not added|could not find' "$work/remove-marketplace.log" || fail "Could not migrate the old PlugLayer marketplace: $1."
  fi
}
migrate_catalog() {
  local catalog="$1" selector="$2" info legacy_name total matches replacement
  [ -f "$catalog" ] || return 0
  [ ! -L "$catalog" ] || fail "Preserving linked catalog: $catalog. Resolve the PlugLayer entry through the native plugin manager."
  info="$(awk -v plugin="$public_name" -v action=inspect -f "$source/catalog.awk" "$catalog")" || fail "Preserving unreadable plugin catalog: $catalog."
  read -r legacy_name total matches <<< "$info"
  [ "$matches" -gt 0 ] || return 0
  # Parse before changing native registration; retain a recoverable catalog copy.
  awk -v plugin="$public_name" -f "$source/catalog.awk" "$catalog" > "$work/catalog.json" || fail "Preserving unreadable plugin catalog: $catalog."
  remove_legacy_plugin "$selector"
  if [ ! -e "$catalog.pluglayer-backup" ]; then cp "$catalog" "$catalog.pluglayer-backup"; fi
  replacement="$(mktemp "$(dirname "$catalog")/.pluglayer-catalog.XXXXXX")"
  cat "$work/catalog.json" > "$replacement"
  mv "$replacement" "$catalog"
}
migrate_public_catalogs() {
  local legacy catalog info legacy_name total matches
  if [ "$target" = codex ]; then
    migrate_catalog "${HOME}/.agents/plugins/marketplace.json" "$public_name@personal"
  fi
  # These paths and identities were created by older Direct installers. Keep
  # mixed/edited marketplaces registered and remove only the public entry.
  for legacy in "${HOME}/.pluglayer/marketplaces/${market_prefix}-"*; do
    [ -d "$legacy" ] || continue
    catalog="$legacy/$catalog_relative"
    [ -f "$catalog" ] || continue
    info="$(awk -v plugin="$public_name" -v action=inspect -f "$source/catalog.awk" "$catalog")" || fail "Preserving unreadable plugin catalog: $catalog."
    read -r legacy_name total matches <<< "$info"
    [[ "$legacy_name" =~ ^pluglayer-direct-([a-f0-9]{12}|local)$ ]] || continue
    [ "$matches" -gt 0 ] || continue
    migrate_catalog "$catalog" "$public_name@$legacy_name"
    if [ "$total" -eq "$matches" ]; then
      remove_legacy_marketplace "$legacy_name"
    fi
  done
}
register_public_marketplace() {
  local old_root info old_name total matches
  if "$cli" plugin marketplace add "$marketplace" < /dev/null > "$work/add.log" 2>&1; then
    cat "$work/add.log"; return 0
  fi
  # Prompt installs can have the same identity backed by the public Git repo.
  # Replace that source only when its catalog contains exclusively our plugin.
  if [ "$target" = codex ]; then
    "$cli" plugin marketplace list < /dev/null > "$work/marketplaces.txt"
    old_root="$(awk '$1 == "pluglayer" {sub(/^pluglayer[ \t]+/, ""); print}' "$work/marketplaces.txt")"
  else
    old_root="$(awk -v action=location -f "$source/catalog.awk" "${HOME}/.claude/plugins/known_marketplaces.json")" || fail 'Could not inspect the existing PlugLayer marketplace.'
  fi
  [ -n "$old_root" ] && [ -f "$old_root/$catalog_relative" ] || fail 'Could not register PlugLayer. Resolve the native marketplace error and retry.'
  info="$(awk -v plugin="$public_name" -v action=inspect -f "$source/catalog.awk" "$old_root/$catalog_relative")" || fail 'Preserving unreadable existing PlugLayer marketplace.'
  read -r old_name total matches <<< "$info"
  [ "$old_name" = pluglayer ] && [ "$total" -gt 0 ] && [ "$total" -eq "$matches" ] || fail 'Preserving a customized PlugLayer marketplace containing other plugins.'
  "$cli" plugin marketplace remove pluglayer < /dev/null
  "$cli" plugin marketplace add "$marketplace" < /dev/null
}
retain_newer_package() {
  local current="$1" manifest="$2" current_version
  [ -L "$current" ] && [ -f "$current/$manifest" ] || return 0
  current_version="$(awk -v action=version -f "$source/catalog.awk" "$current/$manifest")" || fail 'Preserving unreadable installed PlugLayer manifest.'
  if awk -v installed="$current_version" -v requested="$version" 'BEGIN {split(installed,a,"."); split(requested,b,"."); for(i=1;i<=3;i++) {if(a[i]+0>b[i]+0) exit 0; if(a[i]+0<b[i]+0) exit 1} exit 1}'; then
    install_root="$(readlink "$current")"
    version="$current_version"
    say "Keeping the newer installed PlugLayer $version package."
  fi
}
write_public_catalog() {
  local path="$marketplace/$catalog_relative" replacement
  if [ -f "$path" ]; then
    [ ! -L "$path" ] || fail "Preserving linked catalog: $path."
    awk -v plugin="$public_name" -v action=canonical -v expected_path="./plugins/$public_name" -v version="$version" -f "$source/catalog.awk" "$path" > "$work/catalog-updated.json" || fail 'Preserving a customized PlugLayer catalog. Resolve its source or extra plugin entries before retrying.'
    replacement="$(mktemp "$(dirname "$path")/.pluglayer-catalog.XXXXXX")"
    cat "$work/catalog-updated.json" > "$replacement"; mv "$replacement" "$path"
  else
    cat "$work/public-catalog.json" > "$path"
  fi
}
verify_public_registration() {
  "$cli" plugin list < /dev/null > "$work/plugins.txt"
  awk '$1 ~ /^pluglayer-codex-plugin@/ { print }' "$work/plugins.txt" > "$work/public-plugins.txt"
  [ "$(wc -l < "$work/public-plugins.txt" | tr -d ' ')" = 1 ] || fail 'PlugLayer setup is incomplete: another public registration remains. Preserve shared catalogs and resolve it through the native plugin manager.'
  awk -v version="$version" '$1 == "pluglayer-codex-plugin@pluglayer" && $2 == "installed," && $3 == "enabled" && $4 == version { found=1 } END { exit !found }' "$work/public-plugins.txt" || fail 'PlugLayer registration or version could not be verified.'
  cat "$work/public-plugins.txt"
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
"$cli" --help </dev/null >/dev/null || fail "$label could not start. Follow $cli_guide and retry."
if [ "$target" != cursor ]; then
  "$cli" plugin --help </dev/null >/dev/null || fail "Update $label to a version with plugin support, then retry."
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
    public_name=pluglayer-codex-plugin
    market_prefix=codex
    catalog_relative=.agents/plugins/marketplace.json
    marketplace="${HOME}/.pluglayer/marketplaces/codex"
    mkdir -p "$marketplace/.agents/plugins" "$marketplace/plugins"
    retain_newer_package "$marketplace/plugins/pluglayer-codex-plugin" plugin.json
    if [ -L "$marketplace/plugins/pluglayer-codex-plugin" ]; then rm "$marketplace/plugins/pluglayer-codex-plugin"
    elif [ -e "$marketplace/plugins/pluglayer-codex-plugin" ]; then fail "Unmanaged marketplace path exists: $marketplace/plugins/pluglayer-codex-plugin"; fi
    ln -s "$install_root" "$marketplace/plugins/pluglayer-codex-plugin"
    printf '{"name":"pluglayer","interface":{"displayName":"PlugLayer"},"plugins":[{"name":"pluglayer-codex-plugin","source":{"source":"local","path":"./plugins/pluglayer-codex-plugin"},"policy":{"installation":"AVAILABLE","authentication":"ON_INSTALL"},"category":"Developer Tools"}]}\n' > "$work/public-catalog.json"
    write_public_catalog
    register_public_marketplace
    "$cli" plugin add "pluglayer-codex-plugin@pluglayer" < /dev/null
    migrate_public_catalogs
    verify_public_registration
    ;;
  claude-code)
    public_name=pluglayer
    market_prefix=claude
    catalog_relative=.claude-plugin/marketplace.json
    marketplace="${HOME}/.pluglayer/marketplaces/claude"
    mkdir -p "$marketplace/.claude-plugin" "$marketplace/plugins"
    retain_newer_package "$marketplace/plugins/pluglayer" .claude-plugin/plugin.json
    if [ -L "$marketplace/plugins/pluglayer" ]; then rm "$marketplace/plugins/pluglayer"
    elif [ -e "$marketplace/plugins/pluglayer" ]; then fail "Unmanaged marketplace path exists: $marketplace/plugins/pluglayer"; fi
    ln -s "$install_root" "$marketplace/plugins/pluglayer"
    printf '{"name":"pluglayer","owner":{"name":"PlugLayer"},"plugins":[{"name":"pluglayer","source":"./plugins/pluglayer","version":"%s"}]}\n' "$version" > "$work/public-catalog.json"
    write_public_catalog
    register_public_marketplace
    "$cli" plugin install "pluglayer@pluglayer" --scope user < /dev/null
    "$cli" plugin update "pluglayer@pluglayer" --scope user < /dev/null
    migrate_public_catalogs
    "$cli" plugin list < /dev/null
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
    "$cli" plugin install "$install_root" < /dev/null
    "$cli" plugin list < /dev/null
    ;;
esac
# This callback reports files/registration only, never OAuth readiness.
if [ -n "$installed_url" ]; then curl -fsS --max-time 10 -X POST "$installed_url" >/dev/null || say 'Package installed; portal status could not refresh.'; fi
trap - ERR
say "4/4 · PlugLayer $version installed in $label"
say "Restart or reload $label if the plugin is not visible in your current session."
say "Connect PlugLayer through $label's native plugin connection UI when needed."
