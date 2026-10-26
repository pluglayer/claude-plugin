---
name: setup-cicd
description: Set up or repair automatic GitHub deployments for an existing PlugLayer app. Connect the repository and branch, publish the workflow, and verify the first deployment without asking the user to create an API key.
---

# Set up automatic deployments

Use for “deploy on push”, “connect this repo”, “automatic deployments” or GitHub
CI/CD for an existing PlugLayer app. First read `get_agents_md` and relevant app
governance. Keep the same app, slug, domains, storage and existing runtime env.

## Explain the outcome

Say: “I’ll connect this repository to your existing PlugLayer app. Future pushes
to the selected branch will build and deploy automatically. You won’t need to
create or copy a PlugLayer API key.”

Discover the app, repository, default deployment branch and Docker build context.
Ask only when a target is ambiguous. Show the selected repository, branch and app.
Do not ask for repeated permission when the user already requested this setup.

## One-time setup

1. Use the existing PlugLayer OAuth MCP connection. Check the owner can configure
   this app. Read `get_github_deployment(app_id)` before changing a connection.
2. Inspect the repository in the **user's agent workspace**, using local Git or
   its connected GitHub tools. Hosted MCP cannot inspect a local path on the
   user's machine; do not use hosted `inspect_local_github_repo` for that.
3. Reuse available GitHub access. Read the exact repository name, numeric
   repository ID, numeric owner ID and default branch from GitHub's authenticated
   repository metadata. With local GitHub CLI:
   `gh api repos/OWNER/REPO --jq '{repository:.full_name,repository_id:.id,repository_owner_id:.owner.id,branch:.default_branch,push:.permissions.push}'`.
   Use IDs as strings in MCP calls. Check permission to publish workflow changes.
4. If GitHub authentication is missing and the CLI is available, explain:
   “I need GitHub access to publish your deployment workflow. I’ll open GitHub
   sign-in. Complete the browser authorization, and I’ll continue setup.”
   Use `gh auth login --web --scopes workflow`. The user may enter a temporary
   device code directly on GitHub. Never request a personal access token, copy
   an OAuth token, run `gh auth token`, or put credentials into chat or a workflow.
   Existing insufficient CLI scopes can use `gh auth refresh --scopes workflow`.
   A hosted agent needs its GitHub connector; if unavailable, report that precise
   prerequisite. Do not silently install local tooling or invent repository IDs.
5. Call `configure_github_deployment(app_id, repository, repository_id,
   repository_owner_id, branch, workflow_path, expected_revision)`.
   For an existing change, use the revision returned by the read; inspect any
   conflict rather than overwriting it. This grants persistent deploy access to
   that repository's push workflow. Use a unique workflow filename per app.
6. Call `generate_github_actions(project_id, app_id, repo=repository)`.
   Use the returned workflow, path and pinned official actions. No required
   `PLUGLAYER_API_KEY` secret exists in this flow. A backend “release pending”
   response is an actual blocker; do not invent action refs or fall back to
   asking the user for a broad API key.
7. Write the workflow safely. Preserve unrelated jobs; replace an existing
   PlugLayer deployment job coherently so two workflows cannot deploy the app
   on the same push. Set the correct Docker context/Dockerfile for monorepos.
   Preserve `id-token: write`, `contents: read`, the configured exact branch,
   official action pins and one concurrency group per app. This first version
   supports direct push workflows; do not add environments, reusable workflow
   delegation, PR triggers or `pull_request_target`.
8. Commit/push or create a PR using existing authorization and repository rules.
   Respect required reviews; never bypass branch protection. Explain any
   remaining user merge action. Ordinary later pushes need no user approval.
9. Watch the first GitHub run and read `get_github_deployment` afterward.
   Require both a successful workflow and completed PlugLayer rollout. A verified
   identity alone does not mean the deployment succeeded. Use the recorded run,
   task and app status to diagnose failures without exposing secrets.

## Report the actual state

- Local only: “The workflow is prepared locally. Automatic deployment will become
  active after it is pushed and the first run succeeds.”
- PR open: give its link and explain the required merge.
- Awaiting first run: say the connection is configured but deployment is unverified.
- Verified success: “Automatic deployments are active: OWNER/REPO → APP, on pushes
  to BRANCH. The first deployment passed. Future runs need no login or approval.”
- Failure: state whether setup, authentication, build, upload or rollout failed,
  and the next concrete action. Never label a queued task successful.

Optional `PLUGLAYER_BUILD_ENV_JSON` and `PLUGLAYER_ENV_JSON` are application
configuration, not PlugLayer authentication. Request them only when the app
needs them; preserve existing runtime variables by default.

For repair/disconnection and implementation details, read
[the reference](references/github-oidc.md). After meaningful changes, use
`manage-knowledge` to save verified app decisions and setup instructions.
