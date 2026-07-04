# Contributing to PlugLayer Claude Plugin

This repository contains the PlugLayer Claude plugin, its MCP wiring, and user-facing skills.

## Step-by-step contribution flow

1. Star the repository if you want to follow updates.
2. Open an issue first for larger workflow or skill changes.
3. Fork the repository to your own GitHub account.
4. Clone your fork locally.
5. Create a branch from your fork's `dev` branch if it exists. Otherwise branch from `main`.
6. Keep the change focused on one plugin or skill improvement.
7. Validate the plugin JSON and review the skills before pushing.
8. Push your branch to your fork.
9. Open a pull request from your fork branch into the public `dev` branch.
10. Address review feedback in the same branch.
11. Maintainers will review, merge, and later promote the change through the normal release flow.

## Before you start

- Read `README.md`
- Keep contributions focused and easy to review
- For major skill changes, open an issue or discussion first
- Keep every Python source file at or below 500 lines; split larger scripts by responsibility while preserving their CLI and output contracts
- Bump `.claude-plugin/plugin.json` whenever any file in this plugin changes, including docs, skills, installer scripts, MCP config, agents, or metadata

## Good contribution areas

- Skill clarity and reliability
- Better deployment guidance
- Safer defaults in MCP config
- Documentation and onboarding improvements
- Bug fixes in plugin metadata or skill instructions

## Avoid in this repo

- Private company secrets or endpoints
- Admin-only operational instructions unless explicitly requested by maintainers
- Broad behavioral rewrites without examples and testing notes

## Local review checklist

Before opening a PR, validate:

- `.mcp.json` is valid JSON
- skill docs are internally consistent
- examples use public-safe placeholders

Suggested checks:

```bash
python - <<'PY'
import json
print(json.load(open('.mcp.json')))
PY
```

## PR expectations

- Explain what changed
- Show the expected Claude-side user flow
- Mention if any skill names, MCP expectations, or setup instructions changed
- Keep screenshots or transcripts short and relevant when helpful
- Target the public `dev` branch unless a maintainer asks for another base branch

## Security

- Never commit real API keys
- Never commit internal hostnames unless intentionally public
- Treat installer/config snippets as public documentation
- Report security issues privately to maintainers

## Maintainer workflow note

This repository is published from a private source repository. Maintainers may sync changes through controlled public branches and PRs. Please work on feature branches and avoid rewriting shared branch history.
