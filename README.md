# PlugLayer Claude Code Plugin

This plugin connects Claude Code to PlugLayer through the hosted MCP service. No Python, uv, Node, Docker, Git, terminal command, or PlugLayer desktop app is required.

## Setup

1. Open **Setup** in the PlugLayer portal.
2. Choose Claude Code and copy the prompt.
3. Paste it into Claude Code.
4. Run the browser OAuth approval when Claude asks.

Claude stores and refreshes the OAuth connection securely. Never copy an API token into chat. The hosted MCP URL is `https://mcp.pluglayer.com/mcp`.

The plugin includes PlugLayer MCP plus skills for repo inspection, deployment, domains, CI/CD, project metadata, environment updates, feedback, security checks, and deployment repair.

Detailed agent setup: [installation instructions](installation_instruction.md).
