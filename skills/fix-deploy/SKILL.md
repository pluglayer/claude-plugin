---
name: fix-deploy
description: Diagnose and repair a failed PlugLayer deployment by combining PlugLayer logs/status with local repo inspection.
---

# Fix PlugLayer Deployment

Use this skill when a PlugLayer deployment failed, is crash-looping, or is not reachable.

## Debug order
1. Fetch deployment/app status.
2. Fetch recent logs.
3. Identify likely failure class:
   - wrong port
   - wrong start command
   - missing env vars
   - container crash
   - image pull issue
   - missing compute
   - archived compute / archived app recovery case
   - ingress/domain issue
   - compose mismatch
   - missing project or compute setup expectations
4. Inspect the relevant local repo files.
5. Patch the smallest correct fix.
6. Redeploy.
7. Re-check logs/status.

## Common fixes
- bind server to `0.0.0.0`
- align exposed port with real app port
- fix Dockerfile `CMD` / `ENTRYPOINT`
- add missing runtime package or build step
- correct compose service port mapping
- point the user to missing secrets/env vars
- explain clearly when deployment is just still in progress and may need around 10 minutes
- if custom domain is involved, separate app health from DNS verification health
- if compute unexpectedly vanished from user inventory, treat it as an archive/recovery issue first; tell admins to use Admin -> DR archived compute recovery before recreating DB records
- do not recommend hard-deleting product records; prefer archive, repair, restore, adopt, or reprovision language

## Response style
Be concrete and calm:
- what failed
- why it likely failed
- what changed
- whether redeploy succeeded
