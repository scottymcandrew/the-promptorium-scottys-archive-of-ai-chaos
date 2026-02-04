# Procedural Documentation

## Anatomy of a Procedure

A well-structured procedure has these elements:

```markdown
## [Task Name] (verb + noun)

[1-2 sentence context—why and when to do this]

### Prerequisites (if needed)
- Required access or permissions
- Required prior steps

### Steps

1. [Action verb] + [specific instruction].
2. [Action verb] + [specific instruction].
3. [Action verb] + [specific instruction].

[Expected result or confirmation of success]
```

## Step Writing Rules

### Start with Action Verbs

Every step begins with an imperative verb.

| Good | Bad |
|------|-----|
| Click **Save**. | The Save button should be clicked. |
| Enter the API key. | You need to enter the API key. |
| Navigate to **Settings**. | Go into the Settings menu. |

### Common Action Verbs

| Verb | Use For |
|------|---------|
| Click | Buttons, links, menu items |
| Select | Dropdowns, checkboxes, radio buttons |
| Enter | Text fields, passwords |
| Navigate | Moving to a location |
| Open | Files, dialogs, pages |
| Expand | Collapsed sections |
| Copy | Transferring content |
| Paste | Inserting copied content |
| Download | Obtaining files |
| Run | Commands, scripts |

### One Action Per Step

Each step should have one primary action. Split complex steps.

```markdown
# Too much
1. Navigate to Settings, click Security, expand the Authentication section,
   and enter your API key in the field.

# Better
1. Navigate to **Settings > Security**.
2. Expand **Authentication**.
3. In the **API Key** field, enter your key.
```

### Include Specific UI Elements

Tell users exactly what to click.

```markdown
# Vague
1. Go to the settings.
2. Find the security options.

# Specific
1. Click **Settings** in the navigation bar.
2. Select the **Security** tab.
```

## Prerequisites Section

### When to Include

Include prerequisites when the procedure requires:
- Specific permissions or roles
- Prior configuration
- External resources (API keys, credentials)
- Software installation

### Format

```markdown
### Prerequisites

- Admin access to the dashboard
- An API key from the external service
- Completed [initial setup](doc:setup)
```

### What to Exclude

Don't list obvious prerequisites:
- "A computer"
- "An internet connection"
- "Access to the product" (they're reading the docs)

## Expected Results

### Inline Confirmation

For simple procedures, add the result at the end:

```markdown
4. Click **Save**.

The configuration is saved. A confirmation message appears.
```

### Explicit Verification

For critical procedures, add a verification section:

```markdown
### Verify the configuration

1. Navigate to **Settings > Security**.
2. Confirm the API key field shows `••••••••` (masked).
3. Click **Test Connection**.

A green checkmark confirms successful configuration.
```

## Conditional Steps

### Optional Steps

Mark optional steps clearly:

```markdown
3. (Optional) Enable advanced logging for debugging.
```

### Conditional Branches

When steps depend on user choices:

```markdown
4. Select your authentication method:
   - For SSO: Click **Configure SSO** and proceed to [SSO setup](#sso).
   - For local auth: Enter username and password.
```

### Platform-Specific Steps

Use tabs for platform variations:

```markdown
<Tabs groupId="os">
  <TabItem value="windows" label="Windows">
    1. Open PowerShell as Administrator.
    2. Run `Set-ExecutionPolicy RemoteSigned`.
  </TabItem>
  <TabItem value="mac" label="macOS">
    1. Open Terminal.
    2. Run `chmod +x install.sh`.
  </TabItem>
</Tabs>
```

## Procedure Patterns

### Basic Configuration

```markdown
## Configure email notifications

Set up email alerts for critical events.

1. Navigate to **Settings > Notifications**.
2. Click **Add Notification**.
3. In **Type**, select **Email**.
4. Enter the recipient email address.
5. Select the events to trigger notifications.
6. Click **Save**.

The notification appears in the Active Notifications list.
```

### Multi-Part Procedure

```markdown
## Set up the integration

Complete these steps to connect your external service.

### Part 1: Generate credentials

1. Log in to the external service console.
2. Navigate to **API > Credentials**.
3. Click **Generate New Key**.
4. Copy the API key and secret.

:::warning
Store these credentials securely. They cannot be retrieved later.
:::

### Part 2: Configure the connection

1. In your dashboard, navigate to **Integrations**.
2. Click **Add Integration**.
3. Select the service from the list.
4. Paste the API key and secret.
5. Click **Test Connection**.
6. If successful, click **Save**.
```

### Procedure with CLI Commands

```markdown
## Deploy using the CLI

Use the command-line interface for automated deployments.

### Prerequisites
- CLI version 2.0 or later installed
- Authentication configured (`cli auth login`)

### Steps

1. Initialize the deployment:

   ```bash
   cli deploy init --project myproject
   ```

2. Review the deployment plan:

   ```bash
   cli deploy plan
   ```

3. Apply the deployment:

   ```bash
   cli deploy apply
   ```

   When prompted, enter `yes` to confirm.

The deployment completes in 2-5 minutes. Monitor progress in the dashboard.
```

### Troubleshooting in Procedures

Add troubleshooting inline when issues are common:

```markdown
4. Click **Test Connection**.

   If the test fails:
   - Verify the API key is correct
   - Check network connectivity
   - Ensure the service is not in maintenance mode
```

## Anti-Patterns

### Avoid These Procedure Mistakes

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Skipping steps | "Then do the obvious thing" | Document every action |
| Vague locations | "Go to settings" | "Navigate to **Settings > Security**" |
| Missing results | No confirmation of success | Add expected outcome |
| Walls of text | Steps buried in paragraphs | Use numbered lists |
| Assumed knowledge | "Configure as needed" | Specify exact values |
| Outdated screenshots | Don't match current UI | Use text or update images |

### Over-Explanation

Don't explain what users can see:

```markdown
# Over-explained
1. Click the Save button, which is the blue button in the lower right
   corner of the dialog box that says "Save" on it.

# Just right
1. Click **Save**.
```

### Passive Voice in Steps

```markdown
# Passive (wrong)
1. The Save button should be clicked.
2. The form is submitted by pressing Enter.

# Active (right)
1. Click **Save**.
2. Press Enter to submit the form.
```

## Procedure Maintenance

### Keep Procedures Accurate

- Test every procedure before publishing
- Re-test after product updates
- Flag procedures for review on major releases

### Minimize Screenshot Dependency

Text-based procedures are more maintainable:

```markdown
# Fragile (screenshot-dependent)
1. Click the button shown below:
   ![Screenshot of button](image.png)

# Robust (text-based)
1. Click the **Deploy** button in the toolbar.
```

### Version Considerations

When procedures differ by version:

```markdown
<Tabs groupId="version">
  <TabItem value="v2" label="Version 2.x">
    Steps for version 2.x
  </TabItem>
  <TabItem value="v1" label="Version 1.x (Legacy)">
    Steps for version 1.x
  </TabItem>
</Tabs>
```
