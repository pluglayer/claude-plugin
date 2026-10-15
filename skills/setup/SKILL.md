---
name: setup
description: Set up, verify, or repair the PlugLayer plugin installation and hosted OAuth connection; use after install or upgrade.
---

# Set up PlugLayer

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
