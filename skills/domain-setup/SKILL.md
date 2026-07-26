---
name: domain-setup
description: Help a user add, understand, and verify custom DNS records for app domains using provider-aware, registrar-friendly wording.
---

# Help a User Set Up a Custom Domain

Use this skill when the user is attaching a custom domain or is confused by DNS forms.

## Goals
- detect the likely DNS/domain provider first
- confirm that provider with the user before giving final click-path guidance
- map PlugLayer record requirements to registrar field names
- prevent host/name and content/value mixups
- explain root/apex vs `www`
- establish whether the root, `www`, or both hostnames must work
- verify after the user confirms records were added

## Detection flow
1. Run the domain-provider detection script/tool first.
2. If it finds a likely provider and authoritative DNS zone, show both and ask the user to confirm.
3. If it cannot tell, offer several likely providers plus `[you choose]`, and let the user type their own provider name.
4. Only after confirmation should you give provider-tailored guidance.

## Wording rules
- Use `Name / Host` for the left-hand DNS field.
- Use `Content / Value` for TXT values.
- Use `Target` for CNAME records when the provider uses that wording.
- Convert PlugLayer's exact DNS names into the provider's UI host format before giving final instructions.
- Use only the zone-relative label for subdomains when the provider requires it, such as `www` or `_pluglayer-verify.www`.
- Never describe `@` as universally valid. Its availability depends on both the provider and record type.
- Treat the root and `www` as separate exact hostnames. Adding `www.<zone>` to PlugLayer does not route `<zone>`.
- When the user chooses `www`, ask whether the root must also work. If yes, either add/verify/attach the root separately with provider-compatible apex DNS or configure an HTTPS permanent redirect from the root to `www`.
- DNS records cannot perform an HTTP redirect or preserve request paths. The redirect must be configured in the provider's forwarding/redirect feature or another path-preserving HTTP redirect service.
- GoDaddy does not allow a CNAME whose Name is `@`.
- For a single GoDaddy apex domain, do not call `add_custom_domain` for the apex. Add `www.<zone>` to PlugLayer, add GoDaddy `CNAME` Name `www` → Target `cname.apps.pluglayer.io`, then configure **DNS → Forwarding → Add Forwarding** from the root to `https://www.<zone>` using **Permanent (301)** and **Forward only**, without masking.
- Do not invent or copy a current PlugLayer edge IP into an apex A record; PlugLayer does not promise that as a stable routing contract.
- Never tell the user to paste the full domain into the Name / Host field when that provider expects a relative label.

## Record presentation rule
Always present the required DNS records in a markdown table with these columns:
- Type
- Name / Host
- Content / Value / Target
- Description

If a description is not needed, use `-`.

## Flow
1. Check provider and authoritative-zone compatibility before adding the custom domain.
2. Ask whether the root, `www`, or both must work and identify the canonical hostname.
3. If this is a GoDaddy apex, stop before creation and give the `www` + 301 forwarding path above.
4. Otherwise, add the chosen exact hostname in PlugLayer and pass the confirmed provider and DNS zone.
5. If both hostnames will route directly, add, verify, and attach each as a separate PlugLayer custom domain.
6. Show the exact TXT and route records in the table.
7. Explain where each field goes in the DNS UI for the confirmed provider.
8. If the provider UI uses shorthand host labels, say both:
   - what to enter in the provider UI
   - the exact DNS name that PlugLayer is verifying
9. Tell the user:
   - "After you add the records, tell me you've added them and I'll verify and continue."
10. Verify only after they confirm.
11. Test the homepage and a real nested path on every requested hostname. If the root redirects to `www`, confirm `/page-1` and any query string are preserved.
12. If verification fails, explain the specific mismatch instead of just saying it is pending. For an existing GoDaddy apex stuck in `waiting_dns`, direct the user to the `www` + forwarding recovery path.

## Common failure patterns
- TXT host entered as the TXT value
- CNAME target entered as the host
- impossible GoDaddy apex CNAME attempted with Name `@`
- only `www` attached while the root DNS points at PlugLayer, causing a root-only edge 404
- root forwarding that drops `/page-1` and sends every request to the homepage
- full hostname pasted into GoDaddy/Namecheap Host when the UI wanted a zone-relative label
- proxy/flattening causes the route record to appear differently than expected

## Response style
Be explicit and practical:
- what record to add
- where to put each value
- what the provider may call each field
- what PlugLayer is still waiting to see
