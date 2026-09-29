# Cognito

Use **`lgallard/cognito-user-pool/aws`** for Cognito User Pools. How a given pool is configured
(sign-in attributes, password policy, MFA) belongs in that service's
`architecture/<service>/infrastructure.md`, not here.

Most of this file is **apply-time-only traps**: things `terraform plan` accepts and `terraform
apply` rejects. They are recorded because each one costs a failed apply to rediscover.

## Custom Email Content

If a pool needs fully custom email content — a specific house style, or genuine HTML **and**
plain-text bodies — use a **Custom Email Sender Lambda trigger**, not the built-in
`verification_message_template` / `admin_create_user_config` fields.

Those fields only accept a **single body string each**, not true `multipart/alternative`. Once a
Custom Email Sender is configured, **Cognito stops sending any email itself** and hands the Lambda
an encrypted code or temporary password to send instead.

### The KMS key

A Custom Email Sender Lambda needs a **dedicated KMS key**:

- Grant the **`cognito-idp.amazonaws.com` service principal** `Encrypt`/`Decrypt`/`GenerateDataKey*`
  in the **key's own resource policy**. This is a separate AWS service, not an IAM principal in the
  account, so it is **not** covered by the standard root-account delegation statement
- Grant the Lambda's execution role `kms:Decrypt` via its own IAM policy

### The dependency cycle

**Do not add the Lambda's `aws_lambda_permission` to the User Pool module's `depends_on`.** The
permission already depends on the pool's ARN (`source_arn`), and the pool depends on the Lambda's
ARN for `lambda_config_custom_email_sender` — so adding the reverse dependency creates a cycle.

It is not needed for correctness either: **Cognito does not validate invoke permissions when saving
`LambdaConfig`**, only when it actually tries to invoke.

## Apply-Time Validation Traps

### `auto_verified_attributes` including `phone_number`

**AWS rejects `CreateUserPool` outright unless a real `sms_configuration` (SNS role) is already
present** — even if no SMS MFA method is enabled and nothing will ever send an SMS. This is a real
apply-time error that `terraform plan` does not catch.

The minimal fix is an IAM role trusting `cognito-idp.amazonaws.com`, with an `sts:ExternalId`
condition as a confused-deputy guard, scoped to **`sns:Publish` only**.

### `client_write_attributes` omitting a required attribute

**Every app client must have write access to every attribute the pool marks required.** AWS states
it as "all app clients can write user pool required attributes", and enforces it by rejecting
`CreateUserPoolClient` with:

```
InvalidParameterException: Invalid write attributes specified while creating a client
```

So a pool whose schema marks `email` and `name` required cannot have a client with
`client_write_attributes = ["name"]`. The write set has to list both. `terraform plan` accepts the
narrower list; the apply is what fails, and the message names neither the offending attribute nor
the requirement.

**The consequence to design around: withholding client write access cannot be used as a control on
a required attribute.** A pool that signs in on `username_attributes = ["email"]` has made the
email address the account identifier, so "users must not rename their own account" is a natural
rule to want — and the app client is the wrong place to put it, because the attribute is required
and therefore always writable. Reach for these instead:

- `user_attribute_update_settings`'s `attributes_require_verification_before_update`, which is a
  **pool-level** setting and does hold. Without it, `UpdateUserAttributes` moves the identifier to
  an unproven address immediately and resets `email_verified` to false; with it, the pool sends a
  code to the *new* address and keeps the old value live until `VerifyUserAttribute` succeeds
- the frontend simply offering no form for it — real, but defence in depth, not enforcement

**Read attributes carry no such requirement**, and the asymmetry is worth using: an attribute that
should be visible but not client-writable — `email_verified`, say — belongs in the read set and
out of the write set, which AWS permits precisely because it is not required.

### App-client flat-variable defaults

Several of the module's flat-variable defaults for the app client do not survive validation against
a pinned recent AWS provider, and **only fail at apply, not plan**:

| Set explicitly | Why |
| --- | --- |
| `client_default_redirect_uri = null` | The module's own default is `""`, which the provider rejects as too short rather than treating as unset |
| `client_refresh_token_rotation = { feature = "DISABLED", retry_grace_period_seconds = 0 }` | The module's default `{}` still produces a `refresh_token_rotation` block, and the provider now requires `feature` once that block is present at all. **Both fields**, not just `feature`: leaving `retry_grace_period_seconds` as the module's default `null` triggers a *separate* error, `"Provider produced inconsistent result after apply"`, because AWS's API normalises that field to `0` rather than leaving it absent even when rotation is disabled |
| `client_allowed_oauth_flows_user_pool_client = false` | For a direct-auth-only client with no Hosted UI/OAuth. The module's default is `true`, which then requires `client_allowed_oauth_flows`/`client_allowed_oauth_scopes` too — and AWS rejects an OAuth-enabled client with neither |

### `clients` replaces the flat variables wholesale

The module's `clients` variable (a list, for declaring more than one app client on the same pool)
**replaces** the flat-variable default client rather than adding to it. **The moment `var.clients`
is non-empty, the module builds its clients entirely from that list and ignores every `client_*`
flat variable.**

So adding a second app client to a pool that already has one configured via flat variables, by
switching to `clients`, would **silently recreate or drop the existing client.**

Add a plain **`aws_cognito_user_pool_client` resource** instead, referencing the module's `id`
output as `user_pool_id`.

## Cognito-to-Cognito SSO (OIDC federation)

A Cognito User Pool can act as an **OIDC identity provider for another Cognito User Pool**. That is
how one pool federates from another — no SAML setup involved.

**On the identity-provider (upstream) side:**

- A **Hosted UI domain** (the module's `domain` variable — Cognito-prefix, no ACM certificate
  needed). Without one, an OIDC relying party's discovery request has no authorize/token/userinfo
  endpoints to resolve
- A dedicated **OAuth-enabled app client**: confidential, `client_secret` generated,
  `allowed_oauth_flows = ["code"]`, with callback URLs pointing at each onboarded downstream pool's
  own Hosted UI `/oauth2/idpresponse` endpoint — **passed in via a variable, never hardcoded**, the
  same convention as cross-service queue ARNs and URLs

**On the relying-party (downstream) side:**

- Its **own Hosted UI domain**, needed as the redirect target registered in the upstream's callback
  URLs above
- An `identity_providers` entry with `provider_type = "OIDC"` and `provider_details.oidc_issuer` set
  to the upstream's Cognito issuer — `https://cognito-idp.<region>.amazonaws.com/<user_pool_id>`,
  i.e. the upstream's `cognito_user_pool_endpoint` output prefixed with `https://`. **Cognito
  auto-discovers the actual endpoints from that issuer's `.well-known/openid-configuration`**, so
  `authorize_url` / `token_url` / `jwks_uri` never need setting by hand

**To make a pool SSO-only**, exclude `"COGNITO"` from the app client's
`client_supported_identity_providers`. The Hosted UI then only ever shows the federated sign-in
button, never a local username/password form.

`admin_create_user_config_allow_admin_create_user_only = true` is **defence in depth on top of
that, not the actual enforcement point** — do not rely on it alone.

The cross-service onboarding steps a human performs to wire two pools together belong in
`instructions/`, not here.
