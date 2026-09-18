# DNS & Email (Route 53 + SES)

## Delegated Hosted Zones

When a service needs its own sending domain — or any other DNS records — under an existing,
account-wide shared hosted zone, **prefer a dedicated, delegated hosted zone for that service's own
subdomain** over adding records directly into the shared zone:

1. Create an `aws_route53_zone` for the subdomain
2. Delegate it from the parent zone with a **single NS `aws_route53_record`**
   (`name = <subdomain>`, `records = aws_route53_zone.this.name_servers`)

This fully encapsulates the subdomain's DNS in that service's own Terraform root and state — a clean
`terraform destroy` removes the whole subtree, **with no risk of touching unrelated records in the
shared zone.** The cost is one extra hosted zone (~$0.50/month) and one delegation hop, which is
cheap against the alternative of a service's destroy reaching into shared DNS.

- **Look up the parent zone via `data "aws_route53_zone"` (by `name`)** — never hardcode its zone ID
- **Never add anything to the parent zone beyond that one delegation record**

## SES

### Where the sending domain sits

SES sends from the **delegated zone's own apex**, with the service's user-facing hostname (a
CloudFront custom domain, per `reference/frontend-hosting.md`) pushed onto a subdomain like `www.`
instead — keeping "this domain serves web traffic" and "this domain sends email" cleanly separate
within the same delegated zone.

Either arrangement works (SES on a subdomain with the apex free for web, or vice versa). **What
matters is that they do not collide.**

### Domain verification

`aws_ses_domain_identity` plus a TXT record (`_amazonses.<domain>`) in the service's own zone,
**gated behind `aws_ses_domain_identity_verification`** with a `depends_on` the TXT record — so
`terraform apply` does not finish until AWS actually confirms the domain, rather than leaving that
to be checked separately later.

### DKIM

`aws_ses_domain_dkim`, with each of its three `dkim_tokens` turned into a CNAME record
(`<token>._domainkey.<domain>` → `<token>.dkim.amazonses.com`) — standard "Easy DKIM".

### Custom MAIL FROM domain

`aws_ses_domain_mail_from`, with:

- an **MX** record — `10 feedback-smtp.<region>.amazonses.com`
- a **TXT/SPF** record — `v=spf1 include:amazonses.com ~all`

**Without this, mail sends "via amazonses.com".** It costs nothing beyond the DNS records
themselves, so set it up whenever a domain is verified for SES.

AWS requires the MAIL FROM domain to be a **subdomain of the identity domain**, not the identity
domain itself. With the identity on the zone apex, a direct child like `mail.<domain>` already
satisfies that in a single hop — no need to nest it deeper.

## Related

- Fully custom email content (HTML + plain text, or a specific house style) requires a **Custom
  Email Sender** Lambda trigger rather than the identity provider's own message templates — see
  `reference/cognito.md`
