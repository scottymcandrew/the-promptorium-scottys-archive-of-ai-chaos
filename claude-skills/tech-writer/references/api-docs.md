# API & Developer Documentation

## Philosophy

Developer docs are reference material. Developers scan for specific information, copy code samples, and leave. Optimize for lookup speed, not reading experience.

## API Reference Structure

### Endpoint Documentation

```markdown
## [HTTP Method] [Endpoint Path]

[One-line description of what this endpoint does]

### Request

**URL**: `POST /api/v1/resources`

**Authentication**: Bearer token required

**Headers**:
| Header | Value | Required |
|--------|-------|----------|
| `Content-Type` | `application/json` | Yes |
| `Authorization` | `Bearer {token}` | Yes |

**Body Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Resource name (max 255 chars) |
| `type` | enum | Yes | One of: `a`, `b`, `c` |
| `config` | object | No | Configuration options |

### Response

**Success (200)**:
```json
{
  "id": "res_abc123",
  "name": "example",
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Error (400)**:
```json
{
  "error": "validation_error",
  "message": "Name is required"
}
```

### Example

```bash
curl -X POST https://api.example.com/v1/resources \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "example", "type": "a"}'
```
```

## Parameter Documentation

### Required vs Optional

Clearly mark required parameters:

```markdown
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `name` | string | Yes | — | Display name |
| `limit` | integer | No | `100` | Max results |
| `offset` | integer | No | `0` | Skip first N |
```

### Complex Types

Document nested objects with separate tables:

```markdown
**Body Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `config` | object | Configuration settings. See below. |

**`config` Object**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `timeout` | integer | No | Request timeout (seconds) |
| `retries` | integer | No | Retry attempts |
```

### Enums

List all valid values:

```markdown
| Parameter | Type | Values | Description |
|-----------|------|--------|-------------|
| `status` | enum | `active`, `paused`, `deleted` | Current status |
```

## Response Documentation

### Success Responses

Document the happy path clearly:

```markdown
### Response

**Status**: `200 OK`

**Body**:
```json
{
  "data": {
    "id": "abc123",
    "name": "Example Resource"
  },
  "meta": {
    "request_id": "req_xyz"
  }
}
```

**Response Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `data.id` | string | Unique identifier |
| `data.name` | string | Resource name |
| `meta.request_id` | string | Request tracking ID |
```

### Error Responses

Document error formats and codes:

```markdown
### Errors

| Status | Error Code | Description |
|--------|------------|-------------|
| 400 | `validation_error` | Invalid request parameters |
| 401 | `unauthorized` | Missing or invalid token |
| 403 | `forbidden` | Insufficient permissions |
| 404 | `not_found` | Resource doesn't exist |
| 429 | `rate_limited` | Too many requests |

**Error Response Format**:
```json
{
  "error": "error_code",
  "message": "Human-readable description",
  "details": {}
}
```
```

## Code Examples

### Complete, Copy-Paste Ready

Every example should work without modification (except credentials):

```markdown
### Example: Create a resource

```bash
curl -X POST https://api.example.com/v1/resources \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-resource",
    "type": "standard",
    "config": {
      "timeout": 30
    }
  }'
```
```

### Multi-Language Examples

Use tabs for different languages:

```markdown
<Tabs groupId="language">
  <TabItem value="curl" label="cURL">
    ```bash
    curl -X GET https://api.example.com/v1/resources \
      -H "Authorization: Bearer $API_TOKEN"
    ```
  </TabItem>
  <TabItem value="python" label="Python">
    ```python
    import requests

    response = requests.get(
        "https://api.example.com/v1/resources",
        headers={"Authorization": f"Bearer {api_token}"}
    )
    ```
  </TabItem>
  <TabItem value="javascript" label="JavaScript">
    ```javascript
    const response = await fetch("https://api.example.com/v1/resources", {
      headers: { "Authorization": `Bearer ${apiToken}` }
    });
    ```
  </TabItem>
</Tabs>
```

### Error Handling Examples

Show how to handle errors:

```python
response = requests.post(url, json=data, headers=headers)

if response.status_code == 200:
    resource = response.json()["data"]
elif response.status_code == 400:
    error = response.json()
    print(f"Validation error: {error['message']}")
elif response.status_code == 429:
    retry_after = response.headers.get("Retry-After", 60)
    time.sleep(int(retry_after))
    # Retry request
```

## Authentication Documentation

### Authentication Methods

Document each method clearly:

```markdown
## Authentication

The API supports multiple authentication methods.

### Bearer Token

Include the token in the Authorization header:

```
Authorization: Bearer <your-token>
```

### API Key

For service accounts, use API key authentication:

```
X-API-Key: <your-api-key>
```

### OAuth 2.0

For user-context requests, use OAuth 2.0:

1. Redirect to authorization URL
2. Exchange code for token
3. Use token in requests

See [OAuth Setup Guide](doc:oauth-setup) for details.
```

## Pagination

### Standard Pagination

Document the pagination pattern:

```markdown
## Pagination

List endpoints support pagination with `limit` and `offset` parameters.

**Parameters**:
- `limit`: Maximum results per page (default: 100, max: 1000)
- `offset`: Number of results to skip

**Response**:
```json
{
  "data": [...],
  "pagination": {
    "total": 2500,
    "limit": 100,
    "offset": 0,
    "has_more": true
  }
}
```

**Example: Page through all results**:
```python
offset = 0
limit = 100
all_results = []

while True:
    response = client.list_resources(limit=limit, offset=offset)
    all_results.extend(response["data"])

    if not response["pagination"]["has_more"]:
        break
    offset += limit
```
```

## Rate Limiting

Document rate limits clearly:

```markdown
## Rate Limits

API requests are rate limited per authentication token.

| Endpoint | Limit | Window |
|----------|-------|--------|
| `GET /resources` | 1000 | 1 minute |
| `POST /resources` | 100 | 1 minute |
| `DELETE /resources` | 50 | 1 minute |

### Rate Limit Headers

Every response includes rate limit information:

| Header | Description |
|--------|-------------|
| `X-RateLimit-Limit` | Maximum requests allowed |
| `X-RateLimit-Remaining` | Requests remaining |
| `X-RateLimit-Reset` | Unix timestamp when limit resets |

### Handling Rate Limits

When rate limited, you receive a `429` response:

```json
{
  "error": "rate_limited",
  "message": "Too many requests",
  "retry_after": 30
}
```

Wait for `retry_after` seconds before retrying.
```

## SDK Documentation

### Installation

```markdown
## Installation

<Tabs groupId="language">
  <TabItem value="python" label="Python">
    ```bash
    pip install example-sdk
    ```
  </TabItem>
  <TabItem value="javascript" label="JavaScript">
    ```bash
    npm install @example/sdk
    ```
  </TabItem>
</Tabs>
```

### Quick Start

```markdown
## Quick Start

<Tabs groupId="language">
  <TabItem value="python" label="Python">
    ```python
    from example import Client

    client = Client(api_key="your-api-key")
    resources = client.resources.list()
    ```
  </TabItem>
  <TabItem value="javascript" label="JavaScript">
    ```javascript
    import { Client } from "@example/sdk";

    const client = new Client({ apiKey: "your-api-key" });
    const resources = await client.resources.list();
    ```
  </TabItem>
</Tabs>
```

## Best Practices for API Docs

### Always Include

- Complete request/response examples
- All parameters with types and requirements
- All possible error responses
- Working code samples
- Authentication requirements

### Avoid

- Incomplete examples (use `...` or `// etc`)
- Missing error documentation
- Outdated code samples
- Assuming SDK knowledge

### Testing

- Every code sample should be tested
- Update samples when API changes
- Version your documentation with your API
