# OCI Patterns & Knowledge

## Table of Contents
- [Core Concepts](#core-concepts)
- [IAM & Compartments](#iam--compartments)
- [Instance Principals & Dynamic Groups](#instance-principals--dynamic-groups)
- [Gotchas & Debugging](#gotchas--debugging)

## Core Concepts

### Resource Model
Resources are identified by **Oracle Cloud Identifiers (OCIDs)**:
```
ocid1.<resource_type>.<realm>.<region>.<unique_id>
ocid1.instance.oc1.uk-london-1.abcdefgh...
```

### Compartment Hierarchy
```
Tenancy (Root Compartment)
  └── Compartment
        └── Sub-Compartment (up to 6 levels)
              └── Resource
```

**Compartments are the fundamental IAM boundary** — all policies scope permissions within compartments.

## IAM & Policy Syntax

Human-readable policy statements:
```
Allow <subject> to <verb> <resource-type> in <location> [where <conditions>]
```

**Verbs (Strict Privilege Hierarchy):**
1. `inspect` — List resources without viewing metadata/content.
2. `read` — View resource configuration and metadata.
3. `use` — Work with existing resources (cannot create/delete).
4. `manage` — Full administrative control.

### Dynamic Groups & Instance Principals
Grant Compute instances API access without storing keys on-disk:
```
# Dynamic Group Matching Rule
ANY {instance.compartment.id = 'ocid1.compartment.oc1..uniqueid'}

# Policy Assignment
Allow dynamic-group AppInstances to read secret-family in compartment Secrets
```

## Gotchas & Debugging

| Issue | Cause | Remediation |
|-------|-------|-------------|
| `404 NotAuthorizedOrNotFound` | Obscured permissions failure or wrong compartment OCID | Verify group policy verb and compartment OCID. |
| Cannot delete compartment | Active or soft-deleted sub-resources exist | Purge resources in subtree before deleting compartment. |
| API Signature Auth Failure | System clock skew > 5 minutes | Synchronize local system time via NTP. |
