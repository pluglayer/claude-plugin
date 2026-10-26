# PlugLayer Claude Code Plugin

PlugLayer gives Claude Code a direct path from source to a live service on
compute dedicated to your project. The [PlugLayer landing page](https://pluglayer.com)
shows the same flow through its 3D scenes: a platform hub connects source,
app, database, and domain; a compute-fabric field shows placement and capacity;
a rotating database tower represents engines that arrive already wired; and the
marketplace mascot represents ready-to-run apps and tools.

## What it can do

From a plain-English request, the plugin can:

- inspect a repository, Dockerfile, Compose stack, or existing image and explain
  the safest deploy path, including ports, environment, storage, and capacity;
- plan and deploy apps, Compose services, marketplace templates, and databases
  such as Postgres, Mongo, Redis, and Qdrant on dedicated PlugLayer compute;
- connect apps to databases, attach persistent storage, configure project
  metadata and environment variables, and set up verified custom domains;
- read task status, logs, health, usage, and rollout state, then diagnose and
  repair failed deployments with the same backend-owned controls as the portal;
- generate CI/CD workflows, check app security and traffic controls, and share
  redacted product feedback when PlugLayer causes a problem.

The hosted MCP connection keeps Claude Code's actions aligned with the portal's
permissions and safeguards. Explore the product surfaces on the landing page:
[platform](https://pluglayer.com/platform), [dedicated compute](https://pluglayer.com/compute),
[databases](https://pluglayer.com/data-layer), [marketplace](https://pluglayer.com/templates),
and [agent setup](https://pluglayer.com/agents). No Python, uv, Node, Docker,
Git, terminal command, or PlugLayer desktop app is required for setup.

## Setup

1. Open **Setup** in the PlugLayer portal.
2. Choose Claude Code and copy the prompt.
3. Paste it into Claude Code.
4. Run the browser OAuth approval when Claude asks.

Claude stores and refreshes the OAuth connection securely. Never copy an API token into chat. The hosted MCP URL is `https://mcp.pluglayer.com/mcp`.

The plugin includes PlugLayer MCP plus skills for repo inspection, deployment,
domains, CI/CD, project metadata, environment updates, feedback, security, and
deployment repair.

Detailed agent setup: [installation instructions](installation_instruction.md).

## Setup and release checks

Run the bundled `setup` skill after installation or upgrade. It verifies package,
focused agents and hosted OAuth separately. See [CHANGELOG.md](CHANGELOG.md).
Connection values are masked by default; prefer server-side env sync.

The optional session-start hook only adds a short capability reminder. It does
not read files, contact services, change permissions or install dependencies.
Skills and agents remain usable when hooks are disabled by host policy.

### Automatic GitHub deployments

Ask “Set up automatic deployments for this app.” The agent uses your PlugLayer
connection and existing GitHub access. If GitHub access is missing, it guides a
one-time browser sign-in. You do not copy a PlugLayer API key into GitHub.
After the first successful setup, pushes to the connected branch build and deploy
automatically using a short-lived GitHub identity. Repository rules may require
a pull request to install the workflow. The agent reports whether setup is
prepared, awaiting its first run, or verified by a successful deployment.
See [the setup skill](skills/setup-cicd/SKILL.md) for migration and release prerequisites.
