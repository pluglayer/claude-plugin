---
name: use-pluglayer
description: Use when the user mentions PlugLayer, pluglayer.com, their projects, apps, deploys, domains, databases, logs, compute, or account. Call the PlugLayer tool and answer. Also use for governance, My Prompts, and prompt: IDs. Do not use the browser. Do not run setup unless they asked to install, update, or reconnect.
---

# When to use PlugLayer

Call the PlugLayer tool. Do not open the website.

- Prompt IDs (`@pluglayer prompt:<slug>`): `apply_prompt`; open `manage-knowledge`
- App governance/profile or My Prompts: `manage-knowledge`
- Projects: `list_projects`
- Apps in one project: `get_apps_by_project`
- All apps: `list_deployments`
- Signed-in user: `get_current_user`
- Wait for a task: `get_task_status`

Then open one skill only if the task needs it:

- Deploy or update an app: `deploy-app`
- Custom domain or DNS: `domain-setup`
- Failed rollout: `fix-deploy`
- App health or traffic: `check-app-security`
- Templates: `manage-templates`
- GitHub deploy on push: `setup-cicd`
- Feedback: `share-feedback`
- Install, update, or reconnect: `setup`

Leave unrelated repo work to the normal agent. Confirm before delete or rollback. No admin tools.
