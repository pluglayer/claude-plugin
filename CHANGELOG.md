# Changelog

## 1.1.42 — 2026-10-16 (unreleased)

- Direct install starts native sign-in only when a terminal can be opened. Headless runs keep the manual connector step.

## 1.1.41 — 2026-10-15 (unreleased)

- Route PlugLayer questions to the matching tool. Use setup only for install, update, or reconnect, and do not browse the site for data the tools return.
- Direct install opens native PlugLayer sign-in when the agent CLI provides `mcp login`, instead of leaving connector authentication as a separate click.

## 1.1.40 — 2026-10-15 (unreleased)

- Verify setup and native component discovery; keep focused agents available without changing unrelated conversations.
- Document masked connection values, compact template discovery and launch-session cleanup.
- Align version/changelog gates and include marketplace readiness guidance.

## 1.1.39

- Fix public plugin loading, registration and OAuth recovery (2026-10-14, `1478bac`).

## 1.1.38

- Update PlugLayer plugin to version 1.1.38, refining installation scripts by removing unnecessary OAuth prompts and enhancing post-installation user guidance. Revise installation documentation to clarify connection through the native plugin UI and ensure users are informed about necessary actions after installation. Improve overall user experience during the installation process. (2026-10-14, `a6e8387`).

## 1.1.37

- Update installation scripts and documentation for PlugLayer Claude Code plugin to version 1.1.37. Refine OAuth connection prompts in Bash and PowerShell installers for improved user experience. Enhance terminal interaction handling during installation and update installation instructions to reflect the new version. (2026-10-12, `d8983b1`).

## 1.1.36

- Add installation scripts for PlugLayer Claude Code plugin in Bash and PowerShell. Update installation instructions and README to clarify setup and capabilities. Bump plugin version to 1.1.36 and enhance plugin description to reflect new features and improvements. (2026-10-12, `ed3a60b`).

## 1.1.35

- No distinct version declaration exists in this package’s checked-in history; this number is not asserted to have shipped.

## 1.1.34

- Bump public plugin release to 1.1.34 (2026-10-11, `345bcac`).

## 1.1.33

- Update version to 1.1.33 in plugin.json for the pluglayer plugin (2026-10-11, `cd5dd06`).

## 1.1.32

- No distinct version declaration exists in this package’s checked-in history; this number is not asserted to have shipped.

## 1.1.31

- No distinct version declaration exists in this package’s checked-in history; this number is not asserted to have shipped.

## 1.1.30

- Publish per-agent installation instructions (2026-10-11, `03030f9`).

## 1.1.29

- Release OAuth-compatible public plugin packs (2026-10-11, `8e5bf30`).

## 1.1.28

- Bundle native public plugin agents (2026-10-11, `e6e36f2`).

