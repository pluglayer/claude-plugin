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
2. If this is a GoDaddy apex, stop before creation and give the `www` + 301 forwarding path above.
3. Otherwise, add the custom domain in PlugLayer and pass the confirmed provider and DNS zone.
4. Show the exact TXT and route records in the table.
5. Explain where each field goes in the DNS UI for the confirmed provider.
6. If the provider UI uses shorthand host labels, say both:
   - what to enter in the provider UI
   - the exact DNS name that PlugLayer is verifying
7. Tell the user:
   - "After you add the records, tell me you've added them and I'll verify and continue."
8. Verify only after they confirm.
9. If verification fails, explain the specific mismatch instead of just saying it is pending. For an existing GoDaddy apex stuck in `waiting_dns`, direct the user to the `www` + forwarding recovery path.

## Common failure patterns
- TXT host entered as the TXT value
- CNAME target entered as the host
- impossible GoDaddy apex CNAME attempted with Name `@`
- full hostname pasted into GoDaddy/Namecheap Host when the UI wanted a zone-relative label
- proxy/flattening causes the route record to appear differently than expected

## Response style
Be explicit and practical:
- what record to add
- where to put each value
- what the provider may call each field
- what PlugLayer is still waiting to see
