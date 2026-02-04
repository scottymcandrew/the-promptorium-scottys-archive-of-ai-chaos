# Document Types & Structure

## Document Type Selection

Choose the right type based on what the reader needs to accomplish.

| Type | Purpose | Structure | Length |
|------|---------|-----------|--------|
| **Tutorial** | Teach a concept through practice | Hands-on steps with explanation | Long (complete exercise) |
| **How-To Guide** | Accomplish a specific task | Numbered steps, minimal context | Short to medium |
| **Reference** | Look up specific information | Tables, lists, definitions | As needed |
| **Explanation** | Understand concepts | Prose with examples | Medium |
| **Troubleshooting** | Fix a problem | Problem → Solution format | Focused |
| **Release Notes** | Communicate changes | Changelog format | Brief |
| **FAQ** | Answer common questions | Q&A format | Variable |

## Tutorials

Tutorials guide users through a learning experience. The goal is understanding, not just completion.

### When to Use
- Onboarding new users
- Teaching complex concepts
- Introducing new features

### Structure Pattern
```markdown
## What you'll build
Brief description of the end result.

## Prerequisites
- Required access or setup
- Prior knowledge assumed

## Step 1: [Action-oriented title]
Context for why this step matters.

1. First action
2. Second action

What you should see: [expected result]

## Step 2: [Action-oriented title]
...

## Next steps
Links to related tutorials or guides.
```

### Tutorial Principles
- **Repeatable**: Every step must work exactly as written
- **Self-contained**: Include all necessary code and configuration
- **Progressive**: Build complexity gradually
- **Validated**: Test the complete flow before publishing

## How-To Guides

How-to guides help users accomplish specific tasks. They assume the reader knows what they want to do.

### When to Use
- Common operational tasks
- Configuration changes
- One-off procedures

### Structure Pattern
```markdown
## [Task Name]

Brief context (1-2 sentences max).

### Prerequisites
Only if truly necessary.

### Steps
1. First action
2. Second action
3. Third action

### Verification
How to confirm success.
```

### How-To Principles
- **Goal-oriented**: Title describes the outcome
- **Minimal context**: Users came to do, not to learn
- **No alternatives**: Pick one path and document it
- **Fast to follow**: Optimize for quick completion

## Reference Documentation

Reference docs are lookup tables for specific information. Users come with a question and want an answer.

### When to Use
- API documentation
- Configuration options
- Supported values and limits
- Glossaries and definitions

### Structure Pattern
```markdown
## [Resource/Concept Name]

One-line definition.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | string | The display name |
| `enabled` | boolean | Whether the feature is active |

### Examples
Brief usage examples.

### Related
Links to guides that use this reference.
```

### Reference Principles
- **Complete**: Document everything, even defaults
- **Accurate**: Verify every value
- **Consistent**: Same format for same content types
- **Linkable**: Every section should be anchored

## Explanation Documentation

Explanations help users understand how and why things work. They build mental models.

### When to Use
- Architectural concepts
- Design decisions
- Complex workflows
- Background information

### Structure Pattern
```markdown
## How [concept] works

Opening paragraph with the key insight.

### [Component/Stage 1]
Explanation with examples.

### [Component/Stage 2]
Explanation with examples.

### Design considerations
Why it works this way (trade-offs, constraints).

### Related concepts
Links to related explanations.
```

### Explanation Principles
- **Conceptual**: Focus on "why" and "how", not "what to do"
- **Illustrated**: Diagrams and examples help understanding
- **Honest**: Include limitations and trade-offs
- **Linked**: Connect to practical how-to guides

## Troubleshooting Articles

Troubleshooting docs help users diagnose and fix problems.

### When to Use
- Known issues
- Common error messages
- Diagnostic procedures

### Structure Pattern
```markdown
## Problem
Brief description of symptoms.

## Solution
Steps to resolve.

## Cause
Why it happened (helps prevent recurrence).

## Related
Links to related troubleshooting.
```

### Troubleshooting Principles
- **Symptom-first**: Match what the user sees
- **Actionable**: Clear fix, not just explanation
- **Validated**: Confirm the solution works
- **Preventive**: Include how to avoid recurrence

## Frontmatter Schema

All documents require frontmatter metadata.

### Required Fields
```yaml
---
title: "Title in Title Case"     # H1 displayed on page
---
```

### Common Optional Fields
```yaml
---
title: "Full Title for H1"
sidebarTitle: "Short Title"       # Navigation display
excerpt: "Subtitle under title"   # Page subtitle
description: "50-word summary"    # Search results
writer: "owner@company.io"        # Content owner
createdAt: "2024-01-15T10:00:00Z" # ISO-8601
updatedAt: "2024-01-15T10:00:00Z" # ISO-8601
hidden: false                     # Exclude from nav/search
featureFlag: "flag-name"          # Visibility control
---
```

### Title Guidelines
- Maximum 50 characters
- Action-oriented when possible
- Unique across the documentation
- Front-load important words (for search)

## Navigation Structure

### Directory Hierarchy
```
guides/
├── _meta.json           # Section ordering
├── getting-started/
│   ├── _meta.json       # Page ordering within section
│   ├── index.mdx        # Section landing page
│   ├── quickstart.mdx
│   └── concepts/
│       ├── _meta.json
│       ├── index.mdx
│       └── ...
```

### _meta.json for Sections
```json
{
  "sections": [
    { "slug": "getting-started", "title": "Getting Started" },
    { "slug": "configuration", "title": "Configuration" }
  ]
}
```

### _meta.json for Page Order
```json
{
  "order": ["index", "quickstart", "concepts", "advanced"]
}
```

### Index Files (index.mdx)
- Serve as landing pages for sections
- Provide navigation to child pages
- Can contain substantive content
- Define the hierarchy parent
