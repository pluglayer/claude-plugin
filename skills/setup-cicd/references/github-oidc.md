# GitHub automatic deployment contract

- PlugLayer OAuth authorizes setup. GitHub OIDC authorizes each autonomous run.
  Editor logout does not disable a saved deployment connection.
- Backend connections bind immutable repository and owner IDs, the exact branch,
  workflow path, project and app. The first signed run verifies those claims.
- Configure/get/disconnect tools use the public owner-authorized backend routes.
  Never issue deployment credentials through an MCP tool or retrieve a host token.
- The official `github/deploy-oidc` action authenticates, uploads in at most 4 MiB
  chunks, merges optional env, queues the same-app rollout and waits for its task.
  It automatically renews short-lived credentials for long uploads/polling.
- Runtime credentials are limited to one app and run. Backend-owned receipts bind
  uploads/tasks to that run. No account inventory, env reads, terminal, app
  removal, policy administration or arbitrary registry selection is granted.
- Exact branch push events only in this release; custom OIDC subjects, environments,
  reusable workflows and PR deployments require an explicit future extension.
- A retry-safe chunk can be retried. Completion recovers its receipt rather than
  blindly repeating a deployment after an ambiguous transport failure.
- Use `get_github_deployment` for status and revision. For a user-requested
  disconnection call `disconnect_github_deployment(app_id, expected_revision)`.
  This invalidates CI credentials and future exchanges; it does not stop the
  running app or cancel an already accepted deployment.
- When changing repository, branch or workflow, inspect the existing connection,
  use its current revision, update the workflow and verify a new run. Old
  credentials and upload receipts are invalidated by the revision change.
- Local repository authorization and workflow publishing are separate from OIDC.
  Reuse the agent's GitHub connector, local CLI or existing Git transport as
  appropriate. Reading private repository IDs may still need GitHub API access.
- Existing legacy API-key workflows keep using their old official actions during
  migration. Replace them only after the OIDC backend/actions release is ready;
  remove an old GitHub secret only if its other uses are known and removal is
  requested. Never repurpose the editor's OAuth access or refresh token.

