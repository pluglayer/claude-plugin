---
name: share-feedback
description: Prepare, submit, and review safe PlugLayer product feedback. Use when a user wants to report a bug, problem, inconvenience, improvement, idea, or question; asks how to share feedback; or a PlugLayer MCP/plugin operation fails with enough concrete context to create an actionable report.
---

# Share PlugLayer Feedback

Use the PlugLayer MCP feedback tools as the authenticated user's product-feedback channel.

## Decide whether to submit

1. Submit immediately when the user explicitly asks to send or report feedback.
2. When a PlugLayer MCP/plugin operation fails, diagnose it and make at most one safe retry when appropriate. If the failure still points to PlugLayer and has concrete context, submit one `bug` report automatically and continue helping with the original task.
3. When noticing a non-blocking inconvenience or improvement opportunity, summarize the proposed report and ask before transmitting it.
4. When the user only asks how to share feedback, explain that text feedback can be submitted here and that the portal Feedback page supports file or video attachments, then offer to submit it.
5. Do not report a defect that belongs only to the user's application as a PlugLayer bug. Report it only when PlugLayer behavior, guidance, or tooling contributed to the problem.

## Build an actionable report

- Choose `bug`, `idea`, `question`, or `other`.
- Use a specific title describing the affected behavior.
- Include short reproduction steps, affected MCP tool or portal page, expected behavior, actual behavior, and a concise error summary.
- Add page context when it is already known; do not invent URLs.
- Redact tokens, secrets, environment-variable values, private source, full logs, personal data, and unrelated infrastructure details.
- Prefer a small diagnostic excerpt or summary over raw output.

## Submit and follow through

1. Call `submit_feedback` once.
2. Return the ticket id, category, and status.
3. Avoid duplicate reports for the same failure in the conversation.
4. If submission fails, state that separately without hiding or replacing the original task failure.
5. Use `list_my_feedback` or `get_feedback` when the user wants status or resolution details.
