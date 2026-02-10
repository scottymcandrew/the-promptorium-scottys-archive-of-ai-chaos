# Formatting & Components

## Callouts (Admonitions)

Callouts highlight important information. Use them sparingly—overuse dilutes their impact.

### Types

```markdown
:::success
Positive information, tips, feature callouts.
:::

:::info
Neutral information that's good to know but skippable.
:::

:::warning
Important caution—mistakes are possible but recoverable.
:::

:::danger
Critical warning—mistakes may cause data loss or outage.
:::
```

### Custom Titles

Add a custom title in brackets:

```markdown
:::warning[Permissions Required]
Admin access is required to modify these settings.
:::
```

### Callout Selection Guide

| Situation | Callout | Example |
|-----------|---------|---------|
| Feature requires specific license | `:::success` | "Requires Advanced license" |
| Preview/beta feature | `:::success` | "This is a preview feature" |
| Clarifying information | `:::info` | "Values are cached for 5 minutes" |
| Common mistakes | `:::warning` | "Restart required after changes" |
| Permissions needed | `:::warning` | "Requires admin access" |
| Destructive operations | `:::danger` | "This cannot be undone" |
| Breaking changes | `:::danger` | "Deprecated—use X instead" |

### Callout Best Practices

- **One idea per callout**: Don't stack multiple warnings
- **Keep it short**: 1-3 sentences maximum
- **Don't nest**: No callouts inside callouts
- **Position wisely**: Before the action that needs warning

### When to Promote Callouts to Prose

Callouts should be demoted from "framing device" to "aside" when they contain information that:
- Changes whether the reader needs the rest of the page
- Requires multi-sentence explanation or reasoning
- Sets the strategic direction of the guide

**Pattern: Explanation in prose, conclusion in callout**

```markdown
# Before (callout doing too much)
:::danger[Do not do X]
Explanation of why X is dangerous, covering multiple architectural
reasons and edge cases. This is a lot of text in a callout.
:::

# After (prose explains, callout concludes)
The architectural reason X is dangerous is [explanation]. This means
[consequence]. The correct approach is [alternative].

:::danger[Do not do X]
Concise one-sentence summary of the rule.
:::
```

## Expandable Sections

Expandables hide content until clicked. Use for detailed information that would interrupt flow.

### Basic Usage

```markdown
<Expandable title="Advanced configuration options">

Additional configuration details that most users don't need.

</Expandable>
```

### With Icons

```markdown
<Expandable icon="fa-regular fa-gear" title="Configuration details">
Content here.
</Expandable>
```

### With Tags

```markdown
<Expandable title="New feature" tag="preview">
This feature is in preview.
</Expandable>
```

Available tags: `preview`, `cloud`, `code`, `defend`, `sensor`, `recommended`

### When to Use Expandables

- **Advanced options**: Details power users need, beginners don't
- **Long examples**: Multiple code samples or scenarios
- **Platform variations**: OS-specific or version-specific details
- **Supporting information**: Details that support but don't drive the main narrative

### When NOT to Use

- **Critical information**: Warnings, prerequisites, required steps
- **First-time setup**: New users need to see everything
- **Troubleshooting steps**: Don't hide the solution

## Tabs

Tabs show parallel content for different contexts (OS, platform, version).

### Basic Usage

```markdown
<Tabs groupId="os">
  <TabItem value="windows" label="Windows">
    Windows-specific content.
  </TabItem>
  <TabItem value="mac" label="macOS">
    macOS-specific content.
  </TabItem>
  <TabItem value="linux" label="Linux">
    Linux-specific content.
  </TabItem>
</Tabs>
```

### Tab Groups

The `groupId` synchronizes tabs across the page. If a user selects "Windows" in one tab group, all tabs with the same `groupId` switch to Windows.

### When to Use Tabs

- **Installation instructions**: Different per OS
- **Authentication methods**: Multiple options
- **Cloud providers**: AWS/Azure/GCP variations
- **Version differences**: Current vs. legacy

### Tab Best Practices

- **Consistent labels**: Same label text for same concepts
- **Complete content**: Each tab should be self-contained
- **Default first**: Put the most common option first
- **Limit count**: 2-4 tabs maximum

## Tables

Use tables for structured comparison or reference information.

### Basic Table

```markdown
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Display name |
| `enabled` | boolean | No | Default: `true` |
```

### Table Guidelines

- **Aligned columns**: Use consistent alignment
- **Concise cells**: Tables are for scanning, not reading
- **Code in backticks**: Format code values properly
- **Meaningful headers**: Clear column purposes

### When to Use Tables

- Parameter/option documentation
- Feature comparison
- Supported values
- Reference data

### When NOT to Use

- Long descriptions (use lists instead)
- Procedures (use numbered lists)
- Narrative content

## Wizard (Step-by-Step)

Wizards create collapsible step sections for long procedures.

```markdown
%WIZARD_START%

### Step 1: Configure the service

Step 1 content here.

### Step 2: Set up authentication

Step 2 content here.

### Step 3: Deploy

Step 3 content here.

%WIZARD_END%
```

### Closed by Default

```markdown
%WIZARD_START_CLOSED%
...
%WIZARD_END%
```

### When to Use Wizards

- Multi-step procedures that span multiple screens
- Installation or setup workflows
- Complex configuration sequences

## Code Blocks

### Language Specification

Always specify the language for syntax highlighting:

```markdown
```bash
terraform apply
```

```json
{
  "key": "value"
}
```

```yaml
settings:
  enabled: true
```
```

### Code Block with Title

```markdown
```bash title="Install dependencies"
npm install
```
```

### Highlighting Lines

```markdown
```javascript {3-4}
function example() {
  const a = 1;
  const b = 2;  // highlighted
  const c = 3;  // highlighted
}
```
```

## Images

### Image Syntax

```markdown
![Alt text description](https://path/to/image.webp)
```

### Image Best Practices

- **Alt text**: Describe what the image shows
- **WebP format**: Preferred for web
- **Reasonable size**: Optimize for fast loading
- **Avoid text in images**: Inaccessible and hard to update

### When to Use Images

- UI screenshots for complex interfaces
- Architecture diagrams
- Workflow visualizations

### When to Avoid Images

- Simple UI actions (describe in text)
- Configuration examples (use code blocks)
- Information that changes frequently

## Links

### Internal Links

```markdown
See [authentication methods](doc:authentication).
Learn about [the Security Graph](doc:security-graph).
```

### External Links

```markdown
See the [AWS documentation](https://aws.amazon.com/docs).
```

### Anchor Links

Link to specific sections:

```markdown
See [configuration options](#configuration-options).
```

### Link Best Practices

- **Descriptive text**: Never "click here"
- **Relevant context**: Link from related terms
- **Check regularly**: Broken links hurt trust

## Glossary Terms

Define terms consistently across documentation.

### Inline Glossary

```markdown
The <Glossary id="Security Graph" /> provides visibility.
```

### When to Use

- First use of a product-specific term
- Technical terms that may confuse readers
- Acronyms that need expansion

## Reusable Blocks

For content that appears in multiple places, create a reusable block.

### Creating a Block

Create a file in `__blocks__/` with PascalCase naming:

```markdown
<!-- __blocks__/PrerequisitesAdmin.mdx -->
:::warning

This operation requires admin permissions. Verify your role in **Settings > Access**.

:::
```

### Using a Block

```markdown
<PrerequisitesAdmin />
```

### When to Create Blocks

- Repeated prerequisites
- Standard warnings
- Common callouts
- Shared procedure fragments
