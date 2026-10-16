# PlugLayer installation instructions for Claude Code

You are installing the official PlugLayer Claude Code plugin. Follow this
document completely and do not substitute an MCP-only connection for the
plugin.

**Current public release: `1.1.41`**

When checking an existing installation, fetch this file from the official
repository and compare the installed package with this release marker. Verify
the same value in `.claude-plugin/plugin.json` before deciding whether an update
is needed.

1. Read the current release marker above and the package version from
   `.claude-plugin/plugin.json` in the official repository. Inspect the installed
   PlugLayer plugin and its version.
2. Use Claude Code's native plugin/marketplace flow to add
   `https://github.com/pluglayer/claude-plugin` and install `pluglayer`, or
   update it when the installed version is older than the available version.
   Use only `pluglayer@pluglayer`; reuse that marketplace across upgrades and
   portal accounts. Never create another personal or account-specific catalog.
   To migrate older Direct registrations, run the package's `install-common.sh`
   or `install.ps1` yourself with `PLUGLAYER_INSTALL_TARGET=claude-code`,
   `PLUGLAYER_PLUGIN_SOURCE_DIR` set to the package root, and
   `PLUGLAYER_PLUGIN_VERSION` set to its manifest version. Omit portal callback
   URLs. Preserve unrelated catalogs and verify one public registration.
3. Confirm the package contains its skills, seven agents, and hosted MCP
   connection. Reload plugins if the current session needs it.
4. Use the bundled MCP connection at `https://mcp.pluglayer.com/mcp`.
5. Choose OAuth/browser authentication. Open the browser, let the user sign in
   to PlugLayer and approve access, and allow the browser callback to finish.
6. Call `get_current_user` and `list_projects` and inspect the actual results.
7. Report the installed version, loaded components, and whether PlugLayer is
   ready. If the native plugin manager is unavailable, state that exact
   limitation and do not claim installation succeeded.

Do not install Python, uv, pip, Node, Docker, Git, a desktop installer, or a
local PlugLayer connector. Never request or print an API token in chat.

Retain a same-version or newer installation; never downgrade. Perform supported
installation, update, and connection steps yourself using available host tools
or the host's existing native CLI. Do not ask the user to type terminal commands.
Respect host permissions and request only the specific approval or UI action that
you cannot perform. A browser loopback callback is created by the host: keep its
login process running, do not invent authorization URLs or reopen expired callbacks. Never copy the localhost callback URL or authorization code into chat; the native agent must receive it automatically.
If the portal prompt specifies an MCP URL, use that environment for this setup;
otherwise use the production URL above. Do not edit a shared plugin cache to
change its environment. Report any native configuration limitation.

## Portal Direct install

From PlugLayer Portal → Agent setup, choose **Direct install**, select your operating system and Windows terminal when applicable, then run the generated command. The URL is reusable for 10 minutes, checks the native agent CLI, installs missing CLI prerequisites through the official installer, and finishes after registering the plugin. When the agent CLI provides `mcp login`, the installer opens PlugLayer sign-in in the browser. Otherwise, restart or reload the agent if the plugin is not visible, then sign in from Plugins → PlugLayer → Connector → Authenticate. It does not install Python or require a PlugLayer API token.
