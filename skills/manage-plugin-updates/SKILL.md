---
name: manage-plugin-updates
description: Check for and safely install a newer PlugLayer plugin version when the routine MCP check finds one or the user asks about PlugLayer plugin updates.
---

# Manage PlugLayer Plugin Updates

- For routine availability checks, call `check_plugin_updates` without `force` no
  more than once during the first substantive PlugLayer workflow in a
  conversation. The MCP tool enforces a 24-hour cache.
- Do not mention no-update results or routine check failures. Never let a check
  delay or replace the user's actual task.
- When an update exists, tell the user the target, installed version, and exact
  available version once. Ask whether they want that update installed.
- Never update automatically. Only after the user explicitly approves that exact
  target and version, call `update_plugin` with the returned `target`, exact
  `confirmed_version`, and `user_approved=true`.
- If the available version changes before installation, stop and ask again.
- Use the MCP update tool rather than constructing a shell pipeline. It pins the
  accepted public-repository commit and reuses the normal PlugLayer installer.
- Never print or request saved credential values during an update.
- After success, tell the user to restart or reload the target app.

