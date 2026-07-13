# PlugLayer Claude Code Plugin

This plugin connects Claude Code to PlugLayer using the published `pluglayer-mcp` package.

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/pluglayer/claude-plugin/main/install.sh | bash
```

The installer gives the user a branded PlugLayer terminal flow, stages the Claude plugin, asks for a token from [portal.pluglayer.com/tokens](https://portal.pluglayer.com/tokens), and can update or reinstall later without forcing token re-entry. It does not require the Claude Code CLI: when `claude` is available, it also registers the plugin in Claude Code's user plugin scope and creates a `claude-pluglayer` launcher; when only the desktop app is installed, it writes Claude's local plugin registry files and a versioned cache copy so the app can load PlugLayer after restart.

## What it includes
- PlugLayer MCP wiring via `.mcp.json`
- A default `pluglayer-deploy` agent
- Skills for:
  - repo inspection
  - deployment to PlugLayer
  - deployment failure diagnosis
  - custom domain guidance

## Requirements
1. `uvx` must be available where Claude Code runs so the PlugLayer MCP can start.
2. `pluglayer-mcp` must be available through `uvx`.
3. You need a PlugLayer API token from [portal.pluglayer.com/tokens](https://portal.pluglayer.com/tokens).

## Installer behavior

- Stages the plugin under `~/.pluglayer/plugins/claude/pluglayer`
- If the `claude` CLI exists, registers it with `claude plugins marketplace add`, installs it with `claude plugins install --scope user`, and creates a `claude-pluglayer` launcher in `~/.local/bin`
- If only the Claude desktop app exists, updates `~/.claude/plugins/known_marketplaces.json`, `~/.claude/plugins/installed_plugins.json`, and the local plugin cache for desktop loading after restart
- Prompts for a PlugLayer token and lets the user keep or replace it during later updates
- Detects the installed plugin version and offers:
  - update/reinstall PlugLayer for Claude Code
  - update the saved token only

## Local install from this repo

```bash
./install.sh
```

## Manual install step by step
1. Clone or download this plugin folder.
2. Make sure `uvx` can run `pluglayer-mcp`.
3. Create a PlugLayer API token in [portal.pluglayer.com/tokens](https://portal.pluglayer.com/tokens).
4. Export the token in the shell or desktop-app environment where Claude Code will launch the MCP:

```bash
export PLUGLAYER_API_KEY="plk_your_token_here"
```

5. For CLI use, launch Claude Code with this plugin directory:

```bash
claude --plugin-dir .
```

6. For desktop use, fully quit and reopen Claude Code after install so it reloads `~/.claude/plugins/installed_plugins.json`.
7. Inside Claude Code, run `/mcp` and confirm the PlugLayer server is connected.
8. Run `/agents` and confirm `pluglayer-deploy` is available.
9. Use `/reload-plugins` after editing plugin files during development.

## Run locally
From the plugin repository root:

```bash
claude --plugin-dir .
```

Then inside Claude Code:
- run `/mcp` to confirm the PlugLayer server is connected
- run `/agents` to confirm `pluglayer-deploy` is available
- use `/reload-plugins` after editing plugin files

Desktop-only users do not need this CLI command. Use the installer and restart the desktop app so it reloads the local plugin registry.

## MCP configuration used by this plugin

```json
{
  "mcpServers": {
    "pluglayer": {
      "command": "uvx",
      "type": "stdio",
      "args": ["pluglayer-mcp"],
      "env": {
        "PLUGLAYER_API_KEY": "${PLUGLAYER_API_KEY}"
      }
    }
  }
}
```

## Good first prompts
- "Inspect this repo and tell me whether I should deploy it with Dockerfile or docker-compose."
- "Create a PlugLayer project for this repo and deploy it."
- "Build this repo, deploy it to PlugLayer, and use the default domain for now."
- "Help me attach my custom domain and explain exactly what to put in my DNS provider."
- "Why did this PlugLayer deploy fail? Check logs and fix it."

## Current scope
This plugin is strongest for:
- current local repos that need a local image build before deploy
- existing Docker images
- Dockerfile-backed repos
- docker-compose deployments
- failure diagnosis using PlugLayer logs plus local repo inspection
- custom domain onboarding and verification help

For DNS-heavy flows, the plugin should translate PlugLayer's exact DNS names into registrar-friendly host entries when needed, such as `@` for the root domain or `_pluglayer-verify` instead of `_pluglayer-verify.example.com` in GoDaddy-style UIs.

For image deploys, the plugin should prefer PlugLayer's managed mirror flow so Claude can ship public or prebuilt images through the PlugLayer Docker Hub namespace before deployment.

For mirrored image deploys, the plugin relies on admin-configured registries stored in PlugLayer itself. Users do not pass registry credentials through the plugin.

This plugin does not expose PlugLayer admin-only tools. It is scoped to end-user app/project/domain/task flows. Compute inventory and purchasing are read-only, while project owners may attach/detach existing dedicated nodes through backend-guarded tools; users can remove their own apps through MCP, and project removal stays within end-user project flows rather than admin actions.
