# `schema.md`

Every Lambda directory must contain a `schema.md` documenting the Lambda's **input contract**. It is
the authoritative, detailed contract; the `README.md` is the narrative overview (see the
`documentation` skill).

Three required sections:

1. **Summary** — a brief description of the Lambda's purpose and **how it is invoked** (e.g.
   "Triggered by SQS queue `new-users`", "Invoked directly via AWS CLI/SDK", "API Gateway
   `POST /api/auth/login`")

2. **Schema** — the input schema in **TypeScript syntax**, in a fenced code block:
   - use `string` unions for constant/enum options (`"permanent" | "temporary"`)
   - mark optional fields with `?`
   - use JSDoc-style comments for field descriptions where helpful

   TypeScript rather than JSON Schema because it states optionality and unions compactly and reads
   correctly to anyone, including the frontend developers consuming the endpoint.

3. **Examples** — realistic sample JSON inputs **covering all key variations**:
   - each with a brief sentence or two describing the scenario it represents
   - cover the happy path, optional fields, and any meaningful variation (different enum values,
     with and without optional fields)

## Template

````markdown
# Lambda Name

Brief summary of what this Lambda does and how it is invoked.

## Schema

```typescript
interface LambdaInput {
  email: string;
  password: string;
  password_type?: "permanent" | "temporary";
}
```

## Examples

### Permanent password (default)

Creates a user with a permanent password.

```json
{
  "email": "user@example.com",
  "password": "SecureP@ss1"
}
```

### Temporary password

Creates a user who must change their password on first login.

```json
{
  "email": "user@example.com",
  "password": "TempPass1!",
  "password_type": "temporary"
}
```
````
