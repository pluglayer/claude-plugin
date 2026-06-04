# PlugLayer Claude Code Plugin

This plugin connects Claude Code to PlugLayer using the published `pluglayer-mcp` package.

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/pluglayer/pluglayer-claude-plugin/main/install.sh | bash
```

The installer gives the user a branded PlugLayer terminal flow, installs the Claude plugin globally, asks for a token from [portal.pluglayer.com/tokens](https://portal.pluglayer.com/tokens), and can update or reinstall later without forcing token re-entry.

## What it includes
- PlugLayer MCP wiring via `.mcp.json`
- A default `pluglayer-deploy` agent
- Skills for:
  - repo inspection
  - deployment to PlugLayer
  - deployment failure diagnosis
  - custom domain guidance

## Requirements
1. `pluglayer-mcp` must be available through `uvx`
2. You need a PlugLayer API token from [portal.pluglayer.com/tokens](https://portal.pluglayer.com/tokens)
3. The installer stores the token in `~/.pluglayer/credentials.env` and launches Claude through `claude-pluglayer`

## Installer behavior

- Installs the plugin into a global Claude-facing folder under `~/.pluglayer/plugins/claude/pluglayer`
- Creates a `claude-pluglayer` launcher in `~/.local/bin`
- Saves the PlugLayer token once, then lets the user keep or replace it during later updates
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
4. Export the token in the shell where you will launch Claude Code:

```bash
export PLUGLAYER_API_KEY="plk_your_token_here"
```

5. Launch Claude Code with this plugin directory:

```bash
claude --plugin-dir .
```

6. Inside Claude Code, run `/mcp` and confirm the PlugLayer server is connected.
7. Run `/agents` and confirm `pluglayer-deploy` is available.
8. Use `/reload-plugins` after editing plugin files.

## Run locally
From the plugin repository root:

```bash
claude --plugin-dir .
```

Then inside Claude Code:
- run `/mcp` to confirm the PlugLayer server is connected
- run `/agents` to confirm `pluglayer-deploy` is available
- use `/reload-plugins` after editing plugin files

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

This plugin does not expose PlugLayer admin-only tools. It is scoped to end-user app/project/domain/task flows. Compute is read-only through MCP, users can remove their own apps through MCP, and project removal stays within end-user project flows rather than admin actions.
