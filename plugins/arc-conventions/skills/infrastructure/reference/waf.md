# AWS WAF

**All public traffic must be protected by AWS WAF.**

## Where a Web ACL Can Attach

**Every Web ACL attaches to a CloudFront distribution** — for a backend-only API service as much as
for a frontend one.

This is not a stylistic choice: **AWS WAF cannot be associated with an API Gateway HTTP API (v2) at
all.** A `REGIONAL` Web ACL associated via `aws_wafv2_web_acl_association` supports REST (v1) API
*stages*, ALBs, AppSync, Cognito user pools and App Runner — **not HTTP APIs.** So where every API
is an HTTP API, a distribution in front of the API is the only place a Web ACL can sit, which makes
CloudFront the sole public entry point to the API.

> This corrects an earlier version of this convention, which specified a `REGIONAL` Web ACL attached
> straight to an API Gateway. If a service ever does use a REST (v1) API, `REGIONAL` +
> `aws_wafv2_web_acl_association` becomes correct for it again.

## Creating It

- **`scope = "CLOUDFRONT"`**, and the Web ACL resource **must be created via the `us-east-1` API
  endpoint** — an AWS requirement for CloudFront-scoped WAF. CloudFront itself is not regional, so
  this does not conflict with the rest of a service running in another region
- This needs a second, aliased **`provider "aws" { alias = "us_east_1" }`** block in the same
  Terraform root, with `provider = aws.us_east_1` set on the `aws_wafv2_web_acl` resource
- **Associate it via the `web_acl_id` attribute on the CloudFront distribution** (or the
  `web_acl_id` input if using `terraform-aws-modules/cloudfront/aws`). **Do not use
  `aws_wafv2_web_acl_association`** — AWS explicitly disallows associating that resource with a
  CloudFront distribution, and the CloudFront-side attribute wants the Web ACL's **ARN**, not its ID

### `create_before_destroy` is required

Give the `aws_wafv2_web_acl` a `lifecycle { create_before_destroy = true }`.

Anything that changes its `name` — a new prefix, a new environment — **replaces** the Web ACL, and
**WAF refuses to delete one that is still associated with a distribution**
(`WAFAssociatedItemException`). Terraform's default destroy-then-create order can never satisfy
that: the old ACL is only free once the distribution points at the new ARN, which needs the new ACL
to exist first.

**The same applies to an `aws_cloudfront_function` a distribution references**, which fails its
delete with `FunctionInUse` (HTTP 409) for exactly the same reason.

In a `terraform plan`, the correct order reads **`+/-` (create then destroy)**; **`-/+` is the
broken one.**

## Rules

### Managed rule groups

Apply AWS Managed Rule Groups as a baseline:

- `AWSManagedRulesAmazonIpReputationList`
- `AWSManagedRulesCommonRuleSet`
- `AWSManagedRulesKnownBadInputsRuleSet`

### Rate-based rules

**Any Web ACL fronting an API also needs a per-IP `rate_based_statement` rule**, and a tighter one
scoped down to the authentication path prefix where the service has authentication endpoints.

API Gateway stage throttling is a **stage-wide capacity limit, not a per-IP brute-force control**,
and is not a substitute for this.

- **Block with a `custom_response` of 429** rather than WAF's default 403
- **Use a `scope_down_statement` on the URI path** so only the intended traffic counts towards a
  limit. On a distribution that also serves a frontend, an uncounted page load would otherwise
  exhaust the budget on static assets
- **Number rate-based rules from priority 0 and managed rule groups from 10**, so the cheap native
  rules evaluate first and a flood is blocked before managed-rule inspection spends WCUs on it
- **A service with no authentication endpoints gets no auth-path rule** — a rule matching a prefix
  no route uses is dead configuration that *reads* as protection. Say so in a comment where the
  asymmetry with a sibling service would otherwise look like an omission

## Logging

**Every Web ACL needs an `aws_wafv2_web_acl_logging_configuration`** — sampled requests alone retain
too small a window to reconstruct an incident.

CloudWatch Logs is the destination, which brings three constraints:

1. The log group name **must start with `aws-waf-logs-`**
2. It must be **in the same region as the Web ACL** — so `us-east-1` for a CloudFront-scoped one
3. The destination ARN must be passed **without** the trailing `:*` — wrap it in
   `trimsuffix(..., ":*")`

**WAF delivers through `delivery.logs.amazonaws.com`, not the Web ACL's own identity**, so the log
group needs an `aws_cloudwatch_log_resource_policy` for that principal — guarded with
`aws:SourceAccount` / `aws:SourceArn` conditions — and the logging configuration needs a
`depends_on` it.

- Use a **`logging_filter` keeping only `BLOCK`/`COUNT`** requests rather than logging every allowed
  one
- **Declare `authorization` and `cookie` as `redacted_fields`**, so no bearer token or session
  cookie is ever written into a log record
