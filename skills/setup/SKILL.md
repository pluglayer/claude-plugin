---
name: setup
description: Install, update, repair, or reconnect the PlugLayer plugin. Use only when the user asks to install, update, repair, or reconnect. Do not use for projects, apps, deploys, domains, or account questions; use use-pluglayer instead.
---

# Set up PlugLayer

If the user wants projects, apps, status, or a deploy, stop. Use `use-pluglayer` and call the tool. This skill is only for install, upgrade, and reconnect.

Read the bundled `installation_instruction.md` from this package root. Inspect
native plugin inventory and retain one public registration, preserving private
and unrelated plugins. Verify the package version, skills and seven focused
agents; inspect rules and optional hooks when this host supports them.

Use the native OAuth browser connection for the bundled hosted MCP. Never ask
for tokens or install a local MCP runtime. Verify `get_current_user` and
`list_projects`, inspecting tool errors as well as connection status.

For a PlugLayer task, select the relevant bundled skill or agent: deploy,
fix-deploy, domain-setup, setup-cicd, templates, security, or feedback. Do not
change the main agent for unrelated work or deploy anything just to test setup.

Report package version, loaded components, pending reload and OAuth verification
separately. Missing or pending components mean setup is incomplete. Reuse details
already supplied by the user and ask only for choices needed to proceed.
