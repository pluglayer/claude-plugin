"""Native Windows plugin installation shared by public and private entry points."""

from __future__ import annotations

import argparse
import getpass
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from urllib.parse import urlsplit


PRODUCTS = {
    "public": ("PLUGLAYER", ".pluglayer", "pluglayer-mcp", "plk_"),
    "admin": ("PLUGLAYER_ADMIN", ".pluglayer-admin", "pluglayer-admin-mcp", "plka_"),
    "security": ("PLUGLAYER_SECURITY", ".pluglayer-security-ops", "pluglayer-security-ops-mcp", "plks_"),
}
MANIFESTS = {"codex": ".codex-plugin/plugin.json", "claude-code": ".claude-plugin/plugin.json",
             "cursor": ".cursor-plugin/plugin.json", "antigravity": "plugin.json"}


def read_json(path: Path, default: dict) -> dict:
    if not path.exists():
        return default
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object in {path}")
    return value


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".pluglayer-tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def lock_directory(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    if os.name == "nt":
        # Use the current user's SID, so localized account names do not affect ACLs.
        identity = subprocess.check_output(["whoami", "/user", "/fo", "csv", "/nh"], text=True)
        import csv
        sid = next(csv.reader([identity.strip()]))[1]
        subprocess.run(["icacls", str(path), "/inheritance:r", "/grant:r", f"*{sid}:(OI)(CI)F"],
                       check=True, stdout=subprocess.DEVNULL)
    else:
        path.chmod(0o700)


def read_credentials(path: Path) -> dict[str, str]:
    values = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.removeprefix("export ")
            if "=" in line:
                key, value = line.split("=", 1)
                parsed = shlex.split(value)
                if len(parsed) == 1:
                    values[key] = parsed[0]
    return values


def copy_plugin(source: Path, destination: Path, command: str, args: list[str],
                server_name: str, credentials: Path, prefix: str) -> None:
    """Stage before replacement; back up an existing managed plugin for recovery."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix=".pluglayer-stage-", dir=destination.parent))
    try:
        shutil.copytree(source, staged, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns(".venv", "__pycache__", ".pytest_cache", ".git"))
        for filename in (".mcp.json", "mcp.json", "mcp_config.json"):
            config_path = staged / filename
            if not config_path.is_file():
                continue
            config = read_json(config_path, {})
            servers = config.get("mcpServers", config)
            if server_name in servers:
                servers[server_name] = {"command": command, "args": args,
                                        "env": {f"{prefix}_CREDENTIALS_FILE": str(credentials)}}
                write_json(config_path, config)
        if destination.exists():
            backup = destination.with_name(destination.name + ".backup-" + datetime.now().strftime("%Y%m%d%H%M%S%f"))
            destination.rename(backup)
            try:
                staged.rename(destination)
            except Exception:
                backup.rename(destination)
                raise
        else:
            staged.rename(destination)
    finally:
        if staged.exists():
            shutil.rmtree(staged)


def register_codex(home: Path, plugin: str) -> None:
    path = home / ".agents/plugins/marketplace.json"
    data = read_json(path, {"name": "personal", "interface": {"displayName": "Personal"}, "plugins": []})
    data.setdefault("name", "personal")
    entry = {"name": plugin, "source": {"source": "local", "path": f"./plugins/{plugin}"},
             "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}, "category": "Developer Tools"}
    data["plugins"] = [item for item in data.get("plugins", []) if item.get("name") != plugin] + [entry]
    write_json(path, data)
    cli = shutil.which("codex")
    if cli:
        subprocess.run([cli, "plugin", "add", f"{plugin}@{data['name']}"], cwd=home, check=True)
    else:
        print("Open Plugins in Codex and install the plugin from your Personal marketplace.")


def register_claude(home: Path, source: Path, plugin: str, market: str, version: str,
                    copy) -> None:
    cache = home / ".claude/plugins/cache" / market / plugin / version
    copy(source, cache)
    now = datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    known_path = home / ".claude/plugins/known_marketplaces.json"
    installed_path = home / ".claude/plugins/installed_plugins.json"
    known = read_json(known_path, {})
    known[market] = {"source": {"source": "directory", "path": str(source)},
                     "installLocation": str(source), "lastUpdated": now}
    installed = read_json(installed_path, {"version": 2, "plugins": {}})
    entries = installed.setdefault("plugins", {}).setdefault(f"{plugin}@{market}", [])
    previous = next((item for item in entries if item.get("scope") == "user"), {})
    entries[:] = [item for item in entries if item.get("scope") != "user"]
    entries.append({"scope": "user", "installPath": str(cache), "version": version,
                    "installedAt": previous.get("installedAt", now), "lastUpdated": now})
    write_json(known_path, known)
    write_json(installed_path, installed)
    settings_path = home / ".claude/settings.json"
    settings = read_json(settings_path, {})
    settings.setdefault("enabledPlugins", {})[f"{plugin}@{market}"] = True
    write_json(settings_path, settings)


def install(*, target: str, product: str, source: Path, uv: str, home: Path | None = None) -> None:
    home = home or Path.home()
    prefix, folder, package, token_prefix = PRODUCTS[product]
    root = home / folder
    credentials = root / "credentials.env"
    # Remove bootstrap secrets before any dependency/tool subprocess.
    key = os.environ.pop(prefix + "_API_KEY", "")
    url = os.environ.pop(prefix + "_API_URL", "")
    saved = read_credentials(credentials)
    if product == "public":
        key = key or saved.get(prefix + "_API_KEY", "") or getpass.getpass("PlugLayer API token (portal > Setup > API access): ")
        url = url or saved.get(prefix + "_API_URL", "") or "https://api.pluglayer.com"
    if not key.startswith(token_prefix) or any(ord(c) < 32 or ord(c) == 127 for c in key):
        raise ValueError("Missing or invalid PlugLayer credential. Generate a new installer command in the portal.")
    parsed = urlsplit(url)
    if not parsed.hostname or parsed.username or parsed.password or parsed.path not in ("", "/") or parsed.query or parsed.fragment:
        raise ValueError("PlugLayer API URL must be an origin")
    if parsed.scheme != "https" and not (parsed.scheme == "http" and parsed.hostname in {"localhost", "127.0.0.1", "::1"}):
        raise ValueError("PlugLayer requires HTTPS outside local development")
    plugin_source = source if product == "public" else source / "plugins" / target
    manifest = read_json(plugin_source / MANIFESTS[target], {})
    plugin = manifest["name"]
    if not plugin or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789-_" for c in plugin):
        raise ValueError("Invalid plugin name")
    version = manifest.get("version") or (read_json(source / "plugins/codex/.codex-plugin/plugin.json", {}).get("version") if product != "public" else (source / "VERSION").read_text().strip())
    if any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_" for c in version):
        raise ValueError("Invalid plugin version")
    lock_directory(root)
    if product == "public":
        subprocess.run([uv, "tool", "install", "--force", "--python", "3.12", package + "@latest"], check=True)
        command = str(Path(uv).with_name("uvx.exe" if os.name == "nt" else "uvx"))
        args = ["--python", "3.12", package + "@latest"]
    else:
        # Keep installed sources at a stable path after the downloaded archive is cleaned up.
        bundle = Path(tempfile.mkdtemp(prefix=version + "-", dir=root))
        shutil.copytree(source, bundle, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns(".venv", "__pycache__", ".pytest_cache", ".git"))
        subprocess.run([uv, "tool", "install", "--force", "--python", "3.12", str(bundle / "mcp")], check=True)
        bin_dir = subprocess.check_output([uv, "tool", "dir", "--bin"], text=True).strip()
        command = str(Path(bin_dir) / (package + (".exe" if os.name == "nt" else "")))
        if not Path(command).is_file():
            raise RuntimeError("The private MCP executable was not installed")
        args = []
    temporary = credentials.with_suffix(".tmp")
    temporary.write_text(f"{prefix}_API_KEY={shlex.quote(key)}\n{prefix}_API_URL={shlex.quote(url.rstrip('/'))}\n", encoding="utf-8")
    temporary.chmod(0o600)
    temporary.replace(credentials)
    server = {"public": "pluglayer", "admin": "pluglayer-admin", "security": "pluglayer-security-ops"}[product]
    def copy(src, dst):
        copy_plugin(src, dst, command, args, server, credentials, prefix)
    if target == "codex":
        destination = home / "plugins" / plugin
    elif target == "cursor":
        destination = home / ".cursor/plugins/local" / plugin
    elif target == "antigravity":
        destination = home / ".gemini/config/plugins" / plugin
    else:
        destination = root / "plugins/claude" / plugin
    copy(plugin_source, destination)
    if target == "codex":
        register_codex(home, plugin)
    elif target == "claude-code":
        market = {"public": "pluglayer", "admin": "pluglayer-admin", "security": "pluglayer-security-ops"}[product]
        register_claude(home, destination, plugin, market, version, copy)
    elif target == "antigravity":
        copy(destination, home / ".gemini/antigravity-cli/plugins" / plugin)
    if product == "public":
        state = root / "state" / (("claude" if target == "claude-code" else target) + ".env")
        state.parent.mkdir(parents=True, exist_ok=True)
        values = {"PLUGLAYER_TARGET": "claude" if target == "claude-code" else target,
                  "PLUGLAYER_PLUGIN_VERSION": version, "PLUGLAYER_PLUGIN_DIR": str(destination),
                  "PLUGLAYER_INSTALLED_AT": datetime.now(timezone.utc).isoformat()}
        state.write_text("".join(f"export {name}={shlex.quote(value)}\n" for name, value in values.items()), encoding="utf-8")
    print(f"Installed {plugin} for {target}. Restart your coding agent.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=MANIFESTS, required=True)
    parser.add_argument("--product", choices=PRODUCTS, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--uv", required=True)
    install(**vars(parser.parse_args()))
