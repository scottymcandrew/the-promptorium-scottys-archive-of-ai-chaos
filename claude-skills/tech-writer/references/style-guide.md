# Writing Style Guide

## Voice & Tone

### The Core Voice

**Direct. Authoritative. Empathetic.**

The reader is trying to solve a problem. They don't want to wade through pleasantries, qualifications, or marketing speak. They want the answer.

### Voice Characteristics

| Do | Don't |
|----|-------|
| "Click **Save**." | "You might want to click the Save button." |
| "Configure the endpoint before deploying." | "It's generally a good idea to configure the endpoint first." |
| "This action deletes all data permanently." | "Please note that this action may result in data deletion." |
| "The feature requires admin access." | "Unfortunately, this feature is only available to administrators." |

### Tone by Context

| Context | Tone | Example |
|---------|------|---------|
| **Procedures** | Direct, imperative | "Enter the API key. Click Submit." |
| **Warnings** | Urgent but calm | "This cannot be undone. Verify before proceeding." |
| **Explanations** | Conversational but professional | "The system checks permissions before each request." |
| **Errors** | Helpful, not apologetic | "The connection failed. Verify network settings." |

## Grammar & Mechanics

### Active Voice

Write in active voice. The subject performs the action.

```markdown
# Active (preferred)
The system validates the input.
Click Save to confirm changes.
Configure the endpoint before deployment.

# Passive (avoid)
The input is validated by the system.
Changes are confirmed by clicking Save.
The endpoint should be configured before deployment.
```

### Present Tense

Document current behavior, not future actions.

```markdown
# Present (preferred)
The dashboard displays active sessions.
When you save, the system validates the configuration.

# Future (avoid)
The dashboard will display active sessions.
When you save, the system will validate the configuration.
```

### Second Person

Address the reader as "you."

```markdown
# Second person (preferred)
You can configure up to 10 endpoints.
Your changes take effect immediately.

# Third person (avoid)
Users can configure up to 10 endpoints.
The user's changes take effect immediately.
```

### Contractions

Use contractions for a natural tone. Avoid in formal or critical contexts.

```markdown
# Use contractions
You can't undo this action.
It's important to verify the settings.

# Skip contractions for emphasis
You cannot recover deleted data.
```

## Sentence Structure

### Short Sentences

Break long sentences into shorter ones. One idea per sentence.

```markdown
# Too long
When you create a new project, you need to specify the name, region,
and resource limits, and you can optionally configure team access
and enable monitoring.

# Better
Create a new project by specifying the name, region, and resource limits.
Optionally, configure team access and enable monitoring.
```

### Front-Load Information

Put the most important information first.

```markdown
# Front-loaded (preferred)
Restart the service after changing configuration.
Admin access is required to modify security settings.

# Buried (avoid)
After you make changes to the configuration file, you need to restart.
To modify the security settings, you need to have admin access.
```

### Parallel Structure

Use consistent grammatical structure in lists and comparisons.

```markdown
# Parallel (preferred)
The widget can:
- Filter incoming data
- Transform field values
- Route to multiple destinations

# Not parallel (avoid)
The widget can:
- Filter incoming data
- Field values are transformed
- Routing to multiple destinations
```

## Word Choice

### Precise Vocabulary

Use specific terms. Avoid vague language.

| Vague | Precise |
|-------|---------|
| "Some time" | "5 minutes" |
| "Various options" | "Three configuration options" |
| "Many resources" | "Up to 100 instances" |
| "Improved performance" | "50% faster response time" |

### Consistent Terminology

Pick one term and use it everywhere.

| Pick One | Not Both |
|----------|----------|
| Click | Click / Press / Select / Choose |
| User | User / Customer / Account holder |
| Dashboard | Dashboard / Home page / Main screen |
| Configuration | Configuration / Settings / Preferences |

### Avoid Filler Words

Remove words that don't add meaning.

| Remove | Keep |
|--------|------|
| "In order to" | "To" |
| "Is able to" | "Can" |
| "Due to the fact that" | "Because" |
| "At this point in time" | "Now" |
| "It is important to note that" | (delete entirely) |

### Technical Accuracy

Use correct technical terms. Don't oversimplify to the point of incorrectness.

```markdown
# Accurate
The API returns a JSON array of objects.
The function accepts a callback parameter.

# Oversimplified
The API returns some data.
The function takes another function.
```

## Formatting Standards

### Headings

- **No H1 in body**: The title is the only H1
- **Start with H2**: First heading after intro must be H2
- **Sequential levels**: H2 → H3 → H4, never skip
- **Sentence case**: Capitalize first word and proper nouns only
- **No terminal punctuation**: Unless a question

```markdown
## Configure authentication settings    # Good
## Configure Authentication Settings    # Bad (title case)
## Configure authentication settings.   # Bad (period)
```

### Bold Text

Bold is **only** for list item lead terms.

```markdown
# Correct usage
- **API key**: Required for authentication
- **Endpoint URL**: The target server address

# Incorrect usage
The **important** setting is in **Settings > Advanced**.
```

### Italics

Use sparingly for:
- Introducing new terms: *widgets* are reusable components
- Emphasis within technical context
- Titles of external resources

### Code Formatting

Use backticks for:
- Commands: Run `terraform apply`
- Parameters: Set the `timeout` value
- File names: Edit `config.yaml`
- Values: Set to `true`

Use code blocks for:
- Multi-line code
- Configuration examples
- Command output

```markdown
# Inline code
Set `enabled` to `true` in the configuration.

# Code block
```yaml
settings:
  enabled: true
  timeout: 30
```
```

### Lists

Use bullet points for unordered items. Use numbered lists for sequences.

```markdown
# Unordered (no sequence)
The feature supports:
- JSON format
- XML format
- CSV format

# Ordered (sequence matters)
1. Open the configuration file.
2. Locate the settings section.
3. Update the value.
4. Save and close.
```

### Numbers

- Spell out one through nine
- Use numerals for 10 and above
- Always use numerals with units: 5 MB, 3 seconds
- Use numerals in technical contexts: Port 8080, version 2.1

## Punctuation

### Commas

- Use serial comma (Oxford comma): "A, B, and C"
- No comma after "e.g." or "i.e."

### Colons

- Lowercase after colon in running text
- Capitalize after colon if complete sentence follows

### Quotation Marks

- Use for UI element labels: Click "Save"
- Use for literal strings: Enter "localhost"
- Don't use for emphasis (use formatting instead)

## Accessibility

### Alt Text for Images

Describe what the image shows, not what it is.

```markdown
# Good
![Dashboard showing three widgets with error states highlighted in red]

# Bad
![Dashboard screenshot]
![image1.png]
```

### Link Text

Links should be descriptive. Never "click here."

```markdown
# Good
Learn more about [authentication methods](link).
See the [API reference](link) for details.

# Bad
[Click here](link) to learn more.
For more information, [see this page](link).
```

### Heading Structure

Headings create a navigable outline. Users with screen readers navigate by heading.

- Use headings to structure content
- Don't skip heading levels
- Make headings descriptive

## Common Mistakes

### Avoid These Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| "Please note that..." | Filler | Delete it |
| "Simply click..." | Patronizing | "Click..." |
| "Obviously..." | Condescending | Delete it |
| "As you can see..." | Assumes visibility | Describe it |
| "Easy to use" | Marketing speak | Show, don't tell |
| "We recommend..." | Weak | "Use..." |

### Punctuation in Procedures

```markdown
# Correct
1. Click **Save**.
2. Enter the API key.

# Incorrect
1. Click **Save**  (missing period)
2. Enter the API key... (ellipsis)
```

### UI Element References

When referencing UI elements:
- Bold for clickable elements: Click **Save**
- Use exact text from the UI
- Include the element type if ambiguous: Click the **Settings** tab
