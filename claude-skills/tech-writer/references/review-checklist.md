# Review Checklist

## The Three-Pass Review

Technical editing is most effective in passes. Each pass focuses on a different layer.

## Pass 1: Structure

Look at the document from 10,000 feet. Does it make sense as a whole?

### Document Purpose
- [ ] Is the document type appropriate? (guide vs tutorial vs reference)
- [ ] Is the purpose clear from the title and opening?
- [ ] Does the content match the title's promise?
- [ ] Is this the right length for the purpose?

### Information Architecture
- [ ] Are headings descriptive and scannable?
- [ ] Is the hierarchy logical? (H2 → H3 → H4, no skips)
- [ ] Does the structure match the user's journey?
- [ ] Can a reader scan headings to find what they need?

### Section Organization
- [ ] Does each section have a clear purpose?
- [ ] Is information in the expected location?
- [ ] Are prerequisites before procedures?
- [ ] Are related topics grouped together?

### Structural Anti-Patterns
- [ ] No wall-of-text sections (break into subsections)
- [ ] No orphan sections (single subsection under a parent)
- [ ] No premature details (context before specifics)

## Pass 2: Content

Examine each section for accuracy, completeness, and clarity.

### Accuracy
- [ ] Are technical details correct?
- [ ] Do procedures work as documented?
- [ ] Are version numbers and values current?
- [ ] Are screenshots up to date (or should be removed)?

### Completeness
- [ ] Are all necessary steps included?
- [ ] Are prerequisites documented?
- [ ] Are error cases covered?
- [ ] Are there logical gaps in the explanation?

### Clarity
- [ ] Is each sentence understandable on first read?
- [ ] Are technical terms defined or linked?
- [ ] Are examples concrete and realistic?
- [ ] Would a new user understand this?

### Content Anti-Patterns
- [ ] No undefined jargon
- [ ] No assumed knowledge beyond stated prerequisites
- [ ] No vague instructions ("configure as needed")
- [ ] No outdated information

## Pass 3: Style & Polish

Fine-tune language, formatting, and presentation.

### Voice & Tone
- [ ] Is the voice direct and authoritative?
- [ ] Is it active voice, not passive?
- [ ] Is it second person ("you") where appropriate?
- [ ] Is the tone consistent throughout?

### Grammar & Mechanics
- [ ] Are there spelling errors?
- [ ] Are there grammatical errors?
- [ ] Is punctuation correct and consistent?
- [ ] Are sentences parallel in structure?

### Formatting
- [ ] No H1 in body (title is the only H1)
- [ ] First heading is H2, not H3
- [ ] Bold only at start of list items
- [ ] Code formatted with backticks
- [ ] Consistent use of callout types

### Links
- [ ] Do all links work?
- [ ] Is link text descriptive (not "click here")?
- [ ] Are cross-references appropriate?
- [ ] Are there opportunities to add helpful links?

### Style Anti-Patterns
- [ ] No "please" or "please note that"
- [ ] No hedging ("you might want to consider")
- [ ] No marketing language ("powerful", "seamless")
- [ ] No apologetic tone

## Quick Checklist (For Small Edits)

For minor corrections, focus on:

- [ ] Grammar and spelling correct
- [ ] Formatting consistent
- [ ] Links work
- [ ] No obvious factual errors
- [ ] Change doesn't break context

## Frontmatter Review

- [ ] Title present and under 50 characters
- [ ] sidebarTitle if title > 20 characters
- [ ] description for search (if applicable)
- [ ] writer field set correctly
- [ ] Timestamps present (createdAt, updatedAt)

## Callout Review

- [ ] Callout type matches content purpose
- [ ] Callout content is brief (1-3 sentences)
- [ ] Critical warnings use :::danger
- [ ] Permissions/requirements use :::warning
- [ ] Tips and features use :::success or :::info

## Procedure Review

- [ ] Steps are numbered
- [ ] Each step starts with action verb
- [ ] One action per step
- [ ] UI elements are specific
- [ ] Expected results included

## Code Block Review

- [ ] Language specified for syntax highlighting
- [ ] Code is complete and copy-paste ready
- [ ] Variables are clearly marked ($TOKEN, {your-key})
- [ ] Output examples where helpful

## Review Output Format

When providing feedback, use this format:

```markdown
## Summary

[1-2 sentence overview of the document quality]

## Structural Issues

- [Issue description] — [Line/section reference]
- [Issue description] — [Line/section reference]

## Content Issues

- [Issue description] — [Line/section reference]

## Style Issues

- [Issue description] — [Line/section reference]

## Corrections Made

- [Line X]: [old text] → [new text]
- [Line Y]: [old text] → [new text]

## Recommendations

- [Optional improvement suggestion]
```

## Severity Classification

When flagging issues, classify by severity:

| Severity | Description | Action |
|----------|-------------|--------|
| **Critical** | Factually wrong, broken procedures | Must fix before publish |
| **Major** | Confusing structure, missing info | Should fix before publish |
| **Minor** | Style issues, typos | Fix in this edit cycle |
| **Suggestion** | Could be improved | Consider for future |

## Corrective vs Creative Editing

### Corrective Editing (Review Mode)
- Fix errors without changing meaning
- Preserve author voice
- Apply style guide rules
- Flag issues without rewriting

### Creative Editing (When Requested)
- Rewrite for clarity
- Restructure content
- Add missing sections
- Suggest new content

**Default to corrective editing** unless creative editing is explicitly requested.
