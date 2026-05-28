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
2. If it finds a likely provider, show it and ask the user to confirm.
3. If it cannot tell, offer several likely providers plus `[you choose]`, and let the user type their own provider name.
4. Only after confirmation should you give provider-tailored guidance.

## Wording rules
- Use `Name / Host` for the left-hand DNS field.
- Use `Content / Value` for TXT values.
- Use `Target` for CNAME records when the provider uses that wording.
- Mention that some providers use `@` for the root domain.

## Record presentation rule
Always present the required DNS records in a markdown table with these columns:
- Type
- Name / Host
- Content / Value / Target
- Description

If a description is not needed, use `-`.

## Flow
1. Add the custom domain in PlugLayer.
2. Show the exact TXT and route records in the table.
3. Explain where each field goes in the DNS UI for the confirmed provider.
4. Tell the user:
   - "After you add the records, tell me you've added them and I'll verify and continue."
5. Verify only after they confirm.
6. If verification fails, explain the specific mismatch instead of just saying it is pending.

## Common failure patterns
- TXT host entered as the TXT value
- CNAME target entered as the host
- root domain entered incorrectly because the provider wants `@`
- proxy/flattening causes the route record to appear differently than expected

## Response style
Be explicit and practical:
- what record to add
- where to put each value
- what the provider may call each field
- what PlugLayer is still waiting to see
