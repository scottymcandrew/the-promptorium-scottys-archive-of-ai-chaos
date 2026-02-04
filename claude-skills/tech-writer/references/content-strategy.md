# Content Strategy

## Documentation Goals

Every documentation effort should optimize for:

1. **Discoverability**: Users find what they need
2. **Clarity**: Users understand what they find
3. **Accuracy**: Information is correct and current
4. **Completeness**: No critical gaps
5. **Maintainability**: Content stays current over time

## Audience Analysis

### Know Your Readers

Before writing, answer:

| Question | Why It Matters |
|----------|----------------|
| Who is the primary audience? | Determines technical depth |
| What do they already know? | Defines prerequisite level |
| What are they trying to do? | Shapes content focus |
| Where are they in their journey? | Affects detail level |
| How will they find this content? | Influences title and structure |

### Audience Personas

| Persona | Characteristics | Content Needs |
|---------|-----------------|---------------|
| **New User** | First-time, learning basics | Tutorials, concepts, guided setup |
| **Practitioner** | Daily user, knows basics | How-to guides, reference, tips |
| **Administrator** | Manages the system | Configuration, permissions, troubleshooting |
| **Developer** | Integrating/extending | API docs, SDKs, code samples |
| **Evaluator** | Deciding to adopt | Concepts, architecture, comparisons |
| **Internal** | Sales, support, success | Scannable facts, copy-paste content |

## Content Prioritization

### Priority Matrix

| Priority | Criteria | Examples |
|----------|----------|----------|
| **P0** | Blocks core workflows | Setup, authentication, critical errors |
| **P1** | Enables key use cases | Feature guides, integrations |
| **P2** | Improves experience | Tips, advanced options, optimizations |
| **P3** | Nice to have | Edge cases, deep dives, history |

### New Feature Documentation

When a feature launches:

1. **Before launch**: Draft core documentation
2. **At launch**: Publish setup, basic usage, known issues
3. **Post launch**: Add advanced guides based on feedback
4. **Ongoing**: Troubleshooting, FAQs from support

## Information Architecture

### Organizing Principles

**By user task** (preferred):
```
├── Get started
├── Configure authentication
├── Set up integrations
├── Monitor performance
└── Troubleshoot issues
```

**By feature** (use sparingly):
```
├── Dashboard
├── Reports
├── Alerts
└── Settings
```

**By product area** (for complex products):
```
├── Core Platform
│   ├── Get started
│   └── Configuration
├── Security
│   ├── Authentication
│   └── Access control
└── Integrations
    ├── Overview
    └── Available integrations
```

### Navigation Depth

- **3 levels maximum**: Section → Guide → Subguide
- **Flat is better**: Users get lost in deep hierarchies
- **Group logically**: Related content together

### Cross-Linking Strategy

Link when:
- Prerequisite knowledge exists elsewhere
- Related topic deepens understanding
- User might naturally want to go there next

Don't link when:
- It would distract from the current task
- The linked content is obvious
- Too many links (link fatigue)

## Content Types Strategy

### The Four-Doc Model

Adapted from Divio's documentation system:

| Type | Purpose | User State | Style |
|------|---------|------------|-------|
| **Tutorial** | Learning | "Teach me" | Hands-on, guided |
| **How-To** | Doing | "Help me do X" | Direct, practical |
| **Explanation** | Understanding | "Help me understand" | Conceptual, narrative |
| **Reference** | Information | "Just the facts" | Precise, scannable |

### Balance Across Types

Most documentation sets are heavy on How-To and Reference, light on Tutorials and Explanations. Evaluate your balance:

```
Tutorials:    ████░░░░░░ 20% (often lacking)
How-To:       ████████░░ 40%
Explanation:  ██░░░░░░░░ 10% (often lacking)
Reference:    ██████░░░░ 30%
```

## Writing for Search

### Title Optimization

Users search for:
- Error messages: "Connection refused error"
- Tasks: "how to configure SSO"
- Concepts: "what is the security graph"

Write titles that match:
```markdown
# Good
"Configure SSO authentication"
"Connection refused: troubleshooting"
"Security Graph overview"

# Bad
"SSO"
"Connection issues"
"About the graph"
```

### Description Optimization

The description field appears in search results. Make it count:

```yaml
# Good
description: "Configure SAML SSO for enterprise authentication.
Covers identity provider setup, attribute mapping, and testing."

# Bad
description: "This guide covers SSO."
```

## Content Maintenance

### Freshness Signals

- **updatedAt timestamp**: Track when content was last modified
- **Version markers**: Note which product version docs cover
- **Review cycles**: Schedule periodic review for evergreen content

### Content Decay

Documentation decays when:
- Product changes but docs don't
- Screenshots become outdated
- Links break
- Terminology shifts

Combat decay with:
- Automated link checking
- Screenshot minimization
- Version-specific content in tabs
- Regular content audits

### Content Ownership

Every document should have an owner:
- **writer field**: Technical writer responsible
- **Subject matter expert**: PM or engineer for accuracy
- **Review schedule**: When to verify content

## Metrics to Track

### Usage Metrics

| Metric | What It Tells You |
|--------|-------------------|
| Page views | Content popularity |
| Search queries | What users need |
| Zero-result searches | Content gaps |
| Bounce rate | Content quality/relevance |
| Time on page | Engagement level |

### Quality Metrics

| Metric | What It Tells You |
|--------|-------------------|
| Support ticket deflection | Docs effectiveness |
| Feedback ratings | User satisfaction |
| Edit frequency | Content stability |
| Link clicks | Cross-reference usefulness |

## Internal Documentation Strategy

Internal docs (sales, support, GTM) have different needs:

### Internal Audience Needs

- **Extremely scannable**: They're on calls
- **Copy-paste ready**: Sending to customers
- **Always current**: Outdated info damages trust
- **Quick answers**: Not deep explanations

### Internal Content Types

| Type | Purpose | Format |
|------|---------|--------|
| **Battle cards** | Competitive positioning | Bullet points, tables |
| **Talk tracks** | Customer conversations | Short paragraphs |
| **FAQs** | Quick answers | Q&A format |
| **Demo scripts** | Product demos | Step-by-step |
| **Pricing** | Commercial details | Tables, scenarios |

### Internal Style Differences

Internal docs can be:
- More direct (less explanation)
- More casual (but still professional)
- More opinionated (clear recommendations)
- More confidential (competitive info)
