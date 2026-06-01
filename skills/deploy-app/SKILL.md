---
name: deploy-app
description: Deploy a local repo, Docker image, or docker-compose app to the user's infrastructure on PlugLayer using the PlugLayer MCP tools.
---

# Deploy an App to the User's Infrastructure

Use this skill when the user wants to ship an app through PlugLayer.

Databases are part of PlugLayer's **Data Layer**. When the user needs a database, asks whether a database already exists, wants a connection string, wants env vars for a backend, or wants to wire a frontend/backend to a database, prefer the Data Layer flow instead of treating the database as a generic app deploy.

If the app is already deployed and the local repo has git plus a GitHub `origin`, suggest the `setup-cicd` skill after the first successful deploy so the same `app_id` can be updated automatically on push without changing the slug.

## Conversation flow
1. Inspect the repo or artifact first.
2. Analyze the app shape before proposing deployment:
   - frontend
   - backend/API
   - workers / queues
   - databases / caches
   - storage / volumes
   - third-party services
3. Check what the user already has in the target project and broader stack:
   - existing apps in the project
   - likely databases already deployed
   - available database templates in Data Layer
   - whether a database should be provisioned through Data Layer or reused from an existing deployed database
   - whether frontend and backend already exist separately
   - whether they want to deploy databases too or just reuse an existing connection string
4. Based on that analysis, explain a short step-by-step deployment plan and include a recommended option for any non-obvious choice.
5. Check project availability.
   - If the user names a project, use it.
   - If they do not have one, ask what they want to call it and suggest sensible names.
   - Include `[you choose]` as an option when the user wants the agent to decide.
   - Best practice: separate distinct software systems into separate projects.
6. Always ask for the app name before deployment and suggest names that fit the project, for example:
   - `mongo-db`
   - `api-backend`
   - `web-frontend`
   - `<project>-worker`
   - `[you choose]`
7. Treat app name and PlugLayer slug as separate values.
   - App name is the internal display/identity name in PlugLayer.
   - PlugLayer slug is the public route segment for the default PlugLayer URL.
   - Example: if slug is `api`, the URL can look like `https://api.<project>.<user>.apps.pluglayer.io`.
   - Let the user keep them the same or choose different values.
   - Make it clear they can update both later.
8. Before deployment, ask whether they want:
   - the default PlugLayer subdomain for now
   - one of the existing project domains
   - a new custom domain
   Mention they can switch to a custom domain later.
   Make it explicit that changing the PlugLayer slug is different from adding or updating a custom domain.
8. If they choose a custom domain:
   - run provider detection first
   - confirm the detected provider with the user
   - if detection is uncertain, show several provider options plus `[you choose]` and let them type their own
   - only then show DNS record instructions
9. DNS instructions must always be shown in a markdown table with columns:
   - Type
   - Name / Host
   - Content / Value / Target
   - Description
10. Check compute availability.
   - If sizing is unclear, call `estimate_compute`.
   - If compute is missing or zero, call `estimate_compute`, offer PlugLayer compute, share the compute link, and stop deployment until the user completes that step.
   - After the user says they added or purchased compute, always check available compute again before deploying.
11. Check whether this project already has apps.
   - List the available apps for the user.
   - If one likely matches the intended deploy target, ask whether they want to update it, replace it, or add a separate new app.
   - Include a recommended option and `[you choose]` for complex operations.
   - If the namespace already looks full, quota-limited, or occupied by a failed/crash-looping older workload, refuse the separate new-app path by default and steer the user into update or replace flow instead.
12. Choose placement:
   - `personal` when the user explicitly wants dedicated personal compute
   - `shared` when the user explicitly wants shared PlugLayer compute
   - `auto` otherwise
   - Include `[you choose]` when the user delegates the decision.
13. Decide deploy type:
   - local build + image deploy when the current repo should be shipped now
   - Docker image when an image already exists in an allowed listed repository
   - smart docker-compose decomposition when multiple services should run together
   - public Docker Hub image directly for standard databases when a trusted public image already exists
   - Data Layer provisioning when the user needs a database template such as MongoDB, Postgres, MySQL, or Redis
14. Deploy.
15. Tell the user deployment usually takes around 10 minutes and offer to check status later.
16. If they chose a new custom domain, ask them to reply after they add the records so verification can continue.
17. After deployment, retrieve all apps in the project and suggest useful cross-app env updates such as frontend → backend URL or backend → database connection string changes.

## Data Layer workflow
When the user needs any database or asks whether one already exists:

1. First check the target project and broader user stack:
   - list existing apps in the project
   - list user databases
   - decide whether to reuse an existing database or provision a new one
2. If they want a new database, always go through the Data Layer path:
   - list database templates
   - recommend a sensible engine/template when the choice is not obvious
   - check or create the target project
   - ask for database app name
   - ask for PlugLayer slug separately
   - check slug availability before provisioning
3. Before provisioning, inspect the database template env vars:
   - explain required vars
   - explain randomizable secrets
   - make sure the final chosen values are explicit at deploy time
4. Provision the database through Data Layer tools, not generic deploy_image/deploy_compose, unless the user explicitly asks for a custom non-template path.
   - if a standard database image shows up in a generic MCP deploy request, reroute it into the same Data Layer template flow the frontend database wizard uses
5. Poll task status until the database is ready or failed.
6. After provisioning:
   - get database connection details
   - get env vars / connection strings
   - use database lifecycle tools for access changes, restarts, or removals when the user asks
   - suggest concrete follow-up updates for backend, frontend, workers, or other apps
7. If the user asks for troubleshooting:
   - get database logs
   - explain whether the issue is compute, storage/PVC, exposure, auth, or app-level wiring
8. If a database already exists and likely matches the need:
   - recommend reuse first
   - fetch its connection details
   - offer to update the dependent app env vars with those values

## Smart compose workflow
When the user provides a docker-compose stack:

1. Analyze the compose file before deploying it.
2. Split it into separate deploy units instead of treating the whole compose file as one app.
3. For services that match a marketplace database template:
   - provision them through Data Layer
   - keep the original compose service name as the PlugLayer app name when possible so inter-service DNS still makes sense
4. For non-database services with pullable images:
   - deploy each service as its own separate app/pod
   - prefer preserving the single-service compose definition when the service uses compose-specific behavior such as `command`, volumes, or post-deploy hooks
5. For services that use local Docker builds:
   - build them locally first with the compose local-build command helper
   - do a local smoke-test build/run before upload
   - export them as architecture-agnostic OCI archives
   - deploy them through the uploaded-image flow as separate apps
   - when available, use the compose local-build command helper to generate the exact `docker buildx`, smoke-test, and archive export commands per service
6. Before deploying non-database services from compose, make sure any env vars that should point at the newly provisioned databases are rewritten from the real Data Layer connection details instead of the original compose-local hostnames.
7. Before deploying local-build services from compose, make sure startup command overrides, ports, and env vars are carried over into the uploaded-image deploy request.

## Required checks before deploy
- project exists
- app name is confirmed
- at least one ready compute path exists for the chosen placement
- default sizing is explicit unless the user clearly asked for less:
  - storage: at least 5 GB
  - cpu: at least 1 core
  - ram: at least 1 GB
- port is known
- app binds in a network-safe way
- env vars are accounted for
- Dockerfile and env file are detected, created if needed, and tested locally when the repo is being built locally
- destination registry is one of the listed allowed repositories/registries

## PlugLayer MCP actions to prefer
- get current user
- get user context
- update user_context after completed tasks or important learned preferences
- list/create/remove projects
- get project
- get apps by project
- list project domains
- get domains by project
- detect custom domain provider
- estimate compute when sizing is unclear
- list PlugLayer compute options
- get my available compute
- get compute summary
- list registries
- deploy image
- upload image archive and deploy
- deploy compose
- analyze compose deploy plan
- check slug availability before using or changing a PlugLayer slug
- update the PlugLayer route slug for an app
- get app/database connection env vars and connection strings after provisioning
- list database templates
- list user databases
- create database
- get database connection details
- sync database env vars to app
- get database logs
- add / verify / attach custom domains as a separate operation
- get deployment/app status
- get task status
- get logs when needed
- app terminal when troubleshooting a live app, but keep terminal input at or below 10,000 characters and about 350 lines
- remove app when the user explicitly wants to remove it

Compute through MCP is read-only. Do not try to add, archive, remove, or otherwise mutate compute inventory from the plugin/MCP surface. If the user needs more capacity, use estimate + marketplace/shared-compute guidance, or direct an admin to the platform UI for compute administration.
MCP exposes no admin-only functions. Stay within end-user actions only.

## Local repo deploy default
For current-repo deployments:

1. inspect the codebase
2. detect whether a Dockerfile and env file already exist and whether they are correct for production deployment
3. build or improve the Dockerfile so it is:
   - optimized for low size
   - architecture-agnostic
   - reasonably secure
4. understand env vars before build/deploy
   - identify required vars
   - identify vars likely to change after deployment, such as redirect URLs, callback URLs, public API URLs, connection strings, and app slugs
   - update them in advance when safe
   - otherwise ask or clearly inform the user
5. build the image locally
6. test the image locally before pushing it
7. keep temporary deployment files inside `.pluglayer/` in the local repo
8. if the image only exists locally, export it as an OCI archive into `.pluglayer/` and use the uploaded-image deploy flow
9. use plain `deploy_image` only when the source image is already pullable from an allowed listed repository
10. after push/deploy, perform full cleanup for artifacts created during this task:
   - delete the temporary image archive
   - delete any other temporary files in `.pluglayer/`
   - remove only local Docker images that use the PlugLayer temporary tag convention and are recorded by the current task
   - remove only task-specific stopped containers, dangling layers, and other Docker artifacts created by this PlugLayer workflow when they are recorded by the current task
   - required image tag convention for PlugLayer-generated local images: `pluglayer-tmp/<repo-or-project-slug>:task-<task-id>-<service-slug>`
   - required archive/export convention: store task exports only under `.pluglayer/images/<task-id>/<service-slug>.oci.tar`
   - required ownership record: write or maintain a task manifest under `.pluglayer/manifests/<task-id>.json` listing every temporary image tag, container name, and archive path created by that task
   - an image is eligible for cleanup only when both conditions are true:
     1. its tag matches the exact `pluglayer-tmp/...:task-...` convention
     2. the same tag is listed in the current task manifest under `.pluglayer/manifests/<task-id>.json`
   - if either marker is missing, do not delete the image automatically
   - never run machine-wide Docker cleanup as routine deploy cleanup
   - never delete unrelated user images, containers, volumes, networks, or shared caches outside the scope of this PlugLayer task

Cleanup is required. Finishing the deploy means cleaning both filesystem artifacts and Docker artifacts created for that deploy.
Cleanup must stay scoped to PlugLayer-generated artifacts from the current task, not the user's broader Docker environment.
Do not delete images based only on recency, size, repo similarity, or guesswork. Delete only by exact PlugLayer naming plus current-task manifest match.

Do not ask the user for a prebuilt image if the current repo can be built confidently.
Do not push images to any repository that is not listed by PlugLayer.

## Database rule
- If the app is a common database and a trusted public Docker Hub image exists, prefer the public image directly.
- Do not mirror or push those public database images unless there is a very specific reason.
- Before deploying a database, ask whether the user wants the database deployed here or already has one elsewhere and only wants to use the connection string.
- For user-facing database provisioning, prefer Data Layer templates and database tools first.
- Use generic app deploy for databases only when the user explicitly wants a custom database runtime outside the standard Data Layer template path.
- After a database is provisioned, always fetch the concrete connection details before telling the user what to use.
- Treat database connection details as active integration work: suggest exact backend/frontend env changes, not vague advice.

## Env var rule
- Always check likely environment variables before deploy.
- Remember that PlugLayer slug changes affect default PlugLayer URLs, while custom domain changes are a separate routing concern.
- If some env vars may differ in the deployed version, call that out clearly and confirm with the user.
- Remind the user that env vars can be updated later by asking to update them.
- When only env vars change, explain that the app will restart/redeploy.
- After a successful deploy, look at the other apps in the project and suggest concrete env updates when one app now depends on another.
- For databases, fetch the concrete connection details after provisioning and offer to update dependent backend/frontend apps with those exact values.
- Before assigning or changing a PlugLayer slug, check that it is available in the target project.
- If the user says they need a database for an app, be proactive:
  - find whether one already exists
  - otherwise provision it through Data Layer
  - then return with exact env vars / connection strings to wire the app correctly

## Existing app rule
Before deploying into a project that already has one or more apps:

1. inspect the existing apps in that project
2. show the available apps to the user
3. if one looks like the same app, ask the user which path they want:
   - update the existing app
   - replace the existing app
   - add a separate new app
   - `[you choose]`
4. do not silently create duplicates when the user's intent is ambiguous
5. if quota or compute is tight, explain that replacing or removing the old app may be necessary before the new deploy can succeed
6. if the project namespace is already full and a similar app exists, do not continue with a brand-new app deploy unless the user explicitly insists on adding a second app

## Redeploy rule
Before redeploying an existing app:
1. list the relevant existing apps if there is any ambiguity
2. show the app name
3. ask the user to confirm the exact app name
4. keep the existing slug unless the user explicitly asks to change it
5. preserve or raise sizing defaults unless the user explicitly asks to go lower:
   - storage should stay at or above 5 GB by default
   - cpu should stay at or above 1 core by default
   - ram should stay at or above 1 GB by default
   - if the current app is below those values and the user did not force lower sizing, prefer redeploying with at least those defaults
6. if the user changed code, do not just restart the old image:
   - rebuild the image
   - use a new version/tag
   - push or upload that rebuilt image
   - redeploy the existing app with the new image
7. only then redeploy

## Sizing default rule
- For deploys and redeploys, choose sensible defaults even when the user does not specify sizing.
- Default minimum storage is 5 GB unless the user explicitly asks for less.
- Default minimum CPU is 1 core unless the user explicitly asks for less.
- Default minimum RAM is 1 GB unless the user explicitly asks for less.
- If a template, estimate, or current app is already higher, keep the higher sensible value unless the user explicitly asks to reduce it.
- Do not silently go below these defaults just because sizing was omitted.

## Domain guidance
When explaining DNS records:
- say `Name / Host`
- say `Content / Value`
- say `Target` for CNAME when needed
- mention that some providers use `@` for the root domain
- mention that root and `www` sometimes behave differently
- tailor click-path notes to the confirmed provider when possible

After showing DNS instructions, tell the user:
- "After you add the records, tell me you've added them and I'll verify and continue."

## Wording rule
Prefer ownership wording such as:
- your cloud
- your infrastructure
- your app runtime
- your compute

Avoid phrasing like:
- deploy your app to PlugLayer
when what you really mean is deploying onto the user's own compute or assigned infrastructure through PlugLayer.

## Removal rule
- For apps, remove them when the user explicitly asks.
- Do not confuse updating the PlugLayer slug with adding/updating a custom domain; those are separate user choices and separate actions.
- Removal should tear down the runtime workload, revoke active routing/slugs, and mark the app as removed in PlugLayer.
- Do not describe app removal as archival in end-user MCP flows.

## User context rule
- Call `update_user_context` after completed tasks and whenever you learn something useful about the user.
- Good examples:
  - preferred project naming style
  - preferred compute placement
  - whether they usually keep databases separate
  - known backend/frontend/database relationships in a project
  - preferred domain/provider patterns

## Result format
Always summarize:
- deploy type used
- project
- app name
- domain choice used for now
- compute placement
- app status
- public URL if any
- database template / engine and connection details if a database was part of the work
- follow-up env suggestions if relevant
- next step or fix if needed
