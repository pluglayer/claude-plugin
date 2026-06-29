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
   - transient rollout noise from a recreate redeploy (see below)
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
- when a fix requires redeploying an existing app, default to `recreate`; only choose `rolling` when the user explicitly wants the lower-downtime tradeoff
- do not recommend hard-deleting product records; prefer archive, repair, restore, adopt, or reprovision language

## Transient rollout noise (recreate redeploys)
A redeploy of an existing app can fail with a message like `did not become ready within <N>s` even though nothing is wrong with the app. Recognize the signature before touching any code:
- the task's `started_at` → `completed_at` gap is much shorter than the stated `<N>s` timeout
- pod states look like `Failed x1, Pending x1`
- the `Failed` pod has `restarts: 0` and its logs show healthy traffic (e.g. `GET / 200`) right up to the redeploy
- readiness-probe warnings reference pod IPs that belong to the previous revision's pods

What it means: the recreate rollout SIGTERMed the old pod, which exited non-zero and transiently reported phase `Failed` while the new pod was still `Pending` on a cold image import. This is rollout noise, not an app bug.

How to handle it:
- do NOT change ports, probes, bind host, or app code for this signature
- read the error's `Wait result:` detail; if it names a pod from the previous revision, treat the failure as noise
- retry the same redeploy once — it normally passes because the stale pod is gone and the image is already imported on the node
- if the same signature repeats on a current backend (which filters stale pods out of rollout health), capture the `failure_context` and look at node-level image-import time or compute pressure instead of the app

Only treat `Failed`/`CrashLoopBackOff` as a real app failure when the affected pod belongs to the current revision (the new pod-template-hash) and is not terminating.

## Response style
Be concrete and calm:
- what failed
- why it likely failed
- what changed
- whether redeploy succeeded
