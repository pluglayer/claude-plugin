---
name: manage-app-access
description: Configure PlugLayer app IP allowlists, HTTP rate limits, and TCP connection limits. Use to restrict trusted IPs, reduce abusive traffic, tune request limits, or apply an approved security-check mitigation across deployed app types.
---

# Manage app access and traffic limits

Use public PlugLayer MCP `get_app_access_policy` and `update_app_access_policy`.
The backend owns permissions, validation, and ingress enforcement. Do not use
Admin Center, raw cluster commands, or app-terminal firewall edits as substitutes.

## Read and choose the control

1. Resolve the exact app ID/name and project with `list_deployments` or
   `get_apps_by_project`. Read `get_app_access_policy(app_id)` immediately before
   preparing a change. Keep the complete prior policy for comparison and rollback.
   Missing policy or protocol metadata is unknown; never synthesize defaults.
2. Use the reported `access_policy_protocols` to choose the control; app labels
   such as database or template do not determine the ingress protocol. Policies
   cover the app's public routes and custom domains; internal traffic bypasses them.
3. Choose from the evidence and intended audience:
   - HTTP: `average` requests per `period_seconds` per peer IP, with `burst` bucket
     capacity. Compare legitimate sustained load and short peaks before reducing
     limits. These are local per-route, per-Traefik-instance limits, not a global
     app quota or per-account limit. Do not impose a guessed universal threshold.
   - TCP: `tcp_max_connections` limits simultaneous connections per route, not
     queries or new connections per second. Preserve headroom for known pools.
   - Allowlist: non-empty `allowed_cidrs` permits only those IPv4/IPv6 addresses
     and networks; `[]` permits all source IPs. This is an allowlist, not a blocklist.
     Do not put an attacker's IP into it to block that attacker.
4. Accept only user-supplied or previously approved trusted client IPs/CIDRs.
   Account for office/VPN egress, operators, webhooks, monitoring, and integrations.
   Never infer trusted clients from logs, the agent's IP, or an arbitrary forwarded
   header. URLs, website domains, Origin, Referer, and CORS are not IP allowlists.
   Behind a proxy/CDN these controls see the peer IP; allowing the CDN can allow
   all of its visitors, and rate limiting that shared IP can throttle legitimate users.

## Apply within the user's scope

- An explicit settings request or existing authorization to fix suitable issues
  permits the requested change. Do not ask again for an already agreed app/policy.
  A check-only request authorizes inspection and a concrete proposal. Finish the
  diagnosis first, then ask only for missing authorization or trusted CIDRs.
- Explain the exact app, before/after values, affected clients/routes, and rollback.
  Preserve public access unless the user explicitly chooses a restricted audience.
  Clearing/broadening an allowlist or weakening a limit needs explicit intent;
  never do it merely to make a probe pass. Do not change unrelated apps.
- Call `update_app_access_policy` with `app_id`, `confirmed_app_name`, and ALL of
  `http_average`, `http_burst`, `http_period_seconds`, `tcp_max_connections`, and
  `allowed_cidrs`. Copy unchanged fields from the fresh read. An empty CIDR list
  must be intentional; it is never an omitted/default argument.
- The save updates ingress in place without a restart or redeploy. Backend
  validation errors are not invitations to loosen security or bypass permissions.

## Verify and recover

- Re-read `get_app_access_policy` and compare the saved policy with the intended
  values (backend CIDR normalization is expected). Check `applied_routes`; zero
  means no public route was updated, not that traffic protection was proven.
- Recheck `get_deployment_status` and a bounded `get_app_logs` sample. When possible,
  make a few benign requests from a known intended client and check an already
  available excluded client. Do not load-test, spoof IP headers, probe third-party
  hosts, or claim a denied client was tested from the agent's own network.
- Separate saved settings, backend route readback, and observed client behavior.
  A quiet/healthy pod or accepted save alone does not prove abuse stopped.
- If legitimate clients regress after this change, restore the captured prior
  policy within the authorized rollback scope and verify it. Re-read first; if
  another actor changed the policy, do not overwrite their work blindly.
- On timeout, partial apply, or uncertain enforcement, inspect before any retry;
  do not loop writes or keep tightening controls. Report what is known and stop
  further mutations if state cannot be established. If tools/routes are missing,
  report the MCP/backend release mismatch and guide the user to the app's Security
  settings in the portal, without pretending the change was applied.
