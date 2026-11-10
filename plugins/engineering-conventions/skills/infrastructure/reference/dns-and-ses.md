# DNS & Email (Route 53 + SES)

## Delegated Hosted Zones

When a service needs its own sending domain — or any other DNS records — under an existing,
account-wide shared hosted zone, **prefer a dedicated, delegated hosted zone for that service's own
subdomain** over adding records directly into the shared zone:

1. Create an `aws_route53_zone` for the subdomain
2. Delegate it from the parent zone with a **single NS `aws_route53_record`**
   (`name = <subdomain>`, `records = aws_route53_zone.this.name_servers`)

This fully encapsulates the subdomain's DNS in that service's own Terraform root and state, **with
no risk of a change to one service touching unrelated records in the shared zone.** The cost is one
extra hosted zone (~$0.50/month) and one delegation hop.

- **Look up the parent zone via `data "aws_route53_zone"` (by `name`)** — never hardcode its zone ID
- **Never add anything to the parent zone beyond that one delegation record**
- **The delegated zone carries `lifecycle { prevent_destroy = true }`** — see
  `stateful-resources.md`. A recreated zone gets new name servers, so the domain, its certificate
  validation and its email authentication all break until the delegation record catches up

**Diverged from `prototype-conventions`:** there, the selling point of a delegated zone is that a
clean `terraform destroy` removes the whole subtree. A prototype is torn down routinely; a
production domain being destroyed is an outage, so the encapsulation is kept and the easy destroy
is deliberately taken away.

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

### DMARC

A TXT record at **`_dmarc.<domain>`**, with DKIM and the custom MAIL FROM domain already in place:

```
v=DMARC1; p=none; rua=mailto:<reporting address>
```

- **Start at `p=none`**, which only asks receivers to report. Once the aggregate reports show every
  legitimate source passing, move to `p=quarantine`, then `p=reject`. Going straight to `reject`
  bounces mail from any sender nobody remembered — a ticketing system, a marketing tool
- The reporting address is a project value, recorded in the project's conventions file

Major mailbox providers now expect a DMARC record from anyone sending in volume, and without one a
domain can be spoofed with nothing telling receivers to refuse it.

### Bounces and complaints

**Every send goes through a configuration set** (`aws_sesv2_configuration_set`), named on the send
call itself — Terraform passes the set's name to the sending Lambda as an environment variable, and
the Lambda's tests assert it is used. (An identity can carry a default set, but only through the
SESv2 `aws_sesv2_email_identity` resource, not the `aws_ses_domain_identity` used above.) The set
has:

- **an event destination** (`aws_sesv2_configuration_set_event_destination`) publishing at least
  `BOUNCE` and `COMPLAINT` events to an SNS topic, **and something that acts on them** — an `sns-`
  Lambda that marks the address undeliverable, so the application stops sending to it
- **the account-level suppression list** for bounces and complaints, as the backstop

**SES watches the account's bounce and complaint rates and pauses sending for an account that
exceeds them.** An application that keeps mailing hard-bouncing addresses will eventually stop all
of the account's email — every service's in that account, not only its own.

### Leaving the sandbox

Every new account starts in the **SES sandbox**, per region: it can send only to verified addresses,
at a low daily quota. **Request production access for each account and region before the first
production release** — it is reviewed by AWS, not instant, and it is not something Terraform does.
An environment still in the sandbox sends test mail perfectly and real mail not at all.

## Related

- Fully custom email content (HTML + plain text, or a specific house style) requires a **Custom
  Email Sender** Lambda trigger rather than the identity provider's own message templates — see
  `reference/cognito.md`
