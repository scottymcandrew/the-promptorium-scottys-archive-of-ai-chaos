# Troubleshooting Workflows

## Universal Triage Order for Permission & API Errors

When facing `AccessDenied`, `Forbidden`, `AuthorizationFailed`, or `PERMISSION_DENIED`, execute triage strictly in this order:

1. **Scope Mismatch (Most Common):**
   - *AWS:* Check ARN wildcards and cross-account Trust Policies (`sts:ExternalId`).
   - *Azure:* Verify exact Resource ID vs Resource Group vs Subscription hierarchy.
   - *GCP:* Check project ID vs Organization Policy constraints.
2. **Propagation Delay:**
   - IAM propagation times: AWS (10–60s), Azure (up to 10 mins), GCP (60s+). Wait and retry before deeper surgery.
3. **Policy Restrictions / Deny Rules:**
   - *AWS:* Check Service Control Policies (SCPs) at the OU/Org level.
   - *Azure:* Check Deny Assignments and Conditional Access policies.
   - *GCP:* Check Organization Policy constraints (e.g. `gcp.resourceLocations`).
4. **Provider / Service API Unregistered:**
   - *Azure:* Verify `az provider show -n <Namespace>` registration state.
   - *GCP:* Check `gcloud services list --enabled`.
5. **Rate Limits & Quota Saturation:**
   - Check if throttling error is wrapped as a `403` (e.g. GCP KMS quota or AWS STS rate limit). Parse `Retry-After` headers.
