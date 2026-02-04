# Troubleshooting Articles

## Philosophy

Troubleshooting articles rescue users in their moment of frustration. They need to find the problem fast and fix it faster. Every extra word is an obstacle.

## Article Structure

### Standard Template

```markdown
---
title: "[Error/Problem] when [action/context]"
description: "Fix for [symptom] caused by [cause]."
---

## Problem

[1-3 sentences describing the symptom exactly as the user experiences it]

[Error message in code block if applicable]

## Solution

[Immediate steps to fix the problem]

1. First action.
2. Second action.
3. Third action.

[Verification that the fix worked]

## Cause

[Brief explanation of why this happens—helps prevent recurrence]

## Related

- [Related troubleshooting article]
- [Relevant configuration guide]
```

### Minimal Template (Quick Fixes)

```markdown
---
title: "[Error message]"
---

## Problem

[Error message] appears when [action].

## Solution

[Single action or short sequence to fix]

## Cause

[One sentence explanation]
```

## Problem Section

### Describe the Symptom

Write the problem as the user experiences it:

```markdown
# Good
## Problem
Login fails with "Invalid credentials" even when the password is correct.

# Bad
## Problem
There is an authentication issue that may occur under certain circumstances.
```

### Include Error Messages

Quote exact error messages so users can find the article:

```markdown
## Problem

The deployment fails with the following error:

```
Error: Connection refused to endpoint https://api.example.com
```
```

### Symptom Variations

If the same problem manifests differently:

```markdown
## Problem

Connections to the API fail. You may see one of these errors:

- `Connection refused`
- `Connection timed out`
- `Unable to resolve host`
```

## Solution Section

### Lead with the Fix

Don't explain—fix first, explain later.

```markdown
# Good
## Solution

1. Open `config.yaml`.
2. Set `retry_attempts` to `5`.
3. Restart the service.

# Bad
## Solution

This issue occurs because the default retry configuration doesn't account
for network latency in distributed environments. The retry mechanism was
designed for... [300 words later] ...so you need to set retry_attempts to 5.
```

### Step-by-Step Format

Use numbered lists for multi-step solutions:

```markdown
## Solution

1. Navigate to **Settings > Security**.
2. Click **Regenerate Token**.
3. Copy the new token.
4. Update your application configuration.
5. Restart the application.
```

### Single-Action Solutions

For simple fixes, use a direct statement:

```markdown
## Solution

Run `service restart` to apply the pending configuration changes.
```

### Multiple Solutions

When there are multiple possible causes, structure with headings:

```markdown
## Solution

Try these solutions in order:

### Check network connectivity

1. Verify the endpoint is reachable:
   ```bash
   curl -I https://api.example.com/health
   ```
2. If unreachable, check firewall rules.

### Verify credentials

1. Confirm the API key is valid.
2. Check the key hasn't expired.

### Increase timeout

1. Edit `config.yaml`.
2. Set `timeout: 60`.
```

## Cause Section

### Brief Explanation

One paragraph maximum. Help users understand without overwhelming:

```markdown
## Cause

The default timeout of 10 seconds is insufficient for large data transfers.
When the transfer exceeds this limit, the connection terminates before
completion.
```

### When to Include

Include the cause when:
- It helps prevent recurrence
- Users need to understand for future decisions
- It explains why the solution works

Skip when:
- The cause is obvious from the solution
- The explanation is highly technical and unhelpful
- It would significantly lengthen the article

## Prerequisites and Environment

### When to Include Prerequisites

Add prerequisites only when the solution requires them:

```markdown
## Prerequisites

- Admin access to the server
- SSH key configured

## Solution
...
```

### Environment Context

Include environment details when the issue is environment-specific:

```markdown
## Environment

- Kubernetes 1.25+
- Linux-based nodes
- Network policies enabled
```

## Error Message Indexing

### Titles Should Match Errors

Use the exact error message in the title when possible:

```markdown
---
title: "Connection refused to endpoint"
---
```

Or describe the symptom clearly:

```markdown
---
title: "Deployment fails after timeout"
---
```

### SEO-Friendly Descriptions

Include key terms users might search:

```markdown
---
description: "Fix for 'Connection refused' error when deploying to Kubernetes.
Caused by network policy blocking egress traffic."
---
```

## Troubleshooting Patterns

### Configuration Issues

```markdown
## Problem

The service fails to start with `Invalid configuration` error.

## Solution

1. Validate the configuration file:
   ```bash
   service validate config.yaml
   ```
2. Fix any errors reported by the validator.
3. Restart the service.

## Cause

The configuration file contains syntax errors or invalid values.
```

### Permission Issues

```markdown
## Problem

`Access denied` error when attempting to modify resources.

## Solution

1. Verify your user has the required role:
   - Navigate to **Settings > Users**.
   - Find your user and check assigned roles.
2. If missing, request the `Admin` role from your administrator.

## Cause

The operation requires elevated permissions not assigned to your account.
```

### Connection Issues

```markdown
## Problem

`Connection timed out` when connecting to external service.

## Solution

### Check endpoint accessibility

```bash
curl -v https://api.external.com/health
```

If unreachable, verify:
- Network/firewall allows outbound HTTPS
- DNS resolves correctly
- No proxy blocking the connection

### Check credentials

1. Verify API key is correct.
2. Confirm key has not expired.
3. Test with a simple API call.

## Cause

Network configuration, expired credentials, or service outage.
```

### State/Data Issues

```markdown
## Problem

Dashboard shows stale data despite recent updates.

## Solution

1. Clear the cache:
   - Navigate to **Settings > Advanced**.
   - Click **Clear Cache**.
2. Refresh the page.

If data remains stale:
1. Check the data source is connected.
2. Verify sync is running (Status should show "Active").

## Cause

Cache invalidation delay or disconnected data source.
```

## Related Links

Always include related content:

```markdown
## Related

- [Authentication configuration](doc:auth-config)
- [Network requirements](doc:network-reqs)
- [Other connection issues](doc:connection-troubleshooting)
```

## Article Quality Checklist

Before publishing a troubleshooting article:

- [ ] Title matches error message or describes symptom clearly
- [ ] Problem section describes exact user experience
- [ ] Error messages are quoted exactly
- [ ] Solution is actionable and tested
- [ ] Steps are numbered and specific
- [ ] Cause is explained briefly (or omitted if obvious)
- [ ] Related links provided
- [ ] No marketing language or apologies
