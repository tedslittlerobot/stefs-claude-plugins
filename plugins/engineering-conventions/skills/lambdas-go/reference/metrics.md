# Metrics

**Metrics are OpenTelemetry metrics**, recorded through the OpenTelemetry metrics API and exported
over OTLP to **CloudWatch's OpenTelemetry metrics**, where **CloudWatch Omni** reads them. Never
Embedded Metric Format, never a hand-built `PutMetricData` call. The rules here are
language-agnostic, and the `lambdas-node` skill defers to this file for everything but its code.

**Corrected at `engineering-conventions` 0.3.0:** 0.2.0 prescribed Embedded Metric Format — a JSON
log line CloudWatch turns into a metric. AWS now treats EMF and `PutMetricData` as its *classic*
metric model, and recommends OpenTelemetry metrics in its place:

| | OpenTelemetry metrics | Classic (EMF, `PutMetricData`) |
| --- | --- | --- |
| Billed | Per GB ingested; no per-metric charge, storage included | Per metric per month |
| Labels | Up to 150 per data point | Up to 30 dimensions |
| Queried with | PromQL — in Query Studio, in CloudWatch alarms, and by Omni | Metric math and Metrics Insights |
| In the code | The vendor-neutral OpenTelemetry API; only the exporter knows about AWS | An AWS-specific log format |

Omni does not take a copy of metrics: it queries them where CloudWatch Metrics holds them, alongside
the vended metrics of AWS services, Lambda's own `Invocations`, `Errors` and `Duration` among them.

## The Target

| | |
| --- | --- |
| Endpoint | `https://monitoring.<region>.amazonaws.com/v1/metrics` |
| Protocol | OTLP 1.x over **HTTP only — no gRPC**; protobuf or JSON body, optionally gzipped |
| Authentication | **SigV4, signing service `monitoring`**, with the function's own role |
| Permission | `cloudwatch:PutMetricData` on the function's role — OTLP ingestion is authorised, and logged in CloudTrail, as `PutMetricData` |
| Limits | 500 requests per second per account; 1,000 data points and 5 MB uncompressed per request; 150 labels per data point; label values up to 1,024 characters |

CloudWatch also accepts a bearer token (an API key) on this endpoint. **Do not use it from a
Lambda:** it is a long-lived secret to store, rotate and leak, where SigV4 uses the short-lived
credentials the function already has.

OpenTelemetry metrics reached CloudWatch as a public preview in April 2026 in a handful of regions.
Check the endpoint answers in the project's region before relying on it.

## Resource Attributes

Static facts about the emitter go on the **resource**, never repeated on each data point. CloudWatch
turns them into labels, and Omni uses the first two to build its service map:

| Attribute | Value |
| --- | --- |
| `service.name` | The Lambda's directory name — the same value as the `service` key in its logs |
| `service.namespace` | The application the Lambda belongs to. Omni groups every service with the same namespace into one application. A project value, recorded in its conventions file |
| `service.instance.id` | A random UUID generated at init — one per execution environment. See "Temporality" for why it is required |
| `deployment.environment.name` | The environment — `production`, `staging` |

## Instruments and Names

- **Counter, Histogram and Gauge only** — the instrument types CloudWatch documents. Durations are
  histograms in seconds (unit `s`), so PromQL's `histogram_quantile()` answers percentile questions
- **Names follow the OpenTelemetry semantic conventions**: lowercase, dot-separated, a namespace
  then the thing measured — `users.created`, `messages.skipped`. Where a semantic convention already
  defines a metric (`http.client.request.duration`), use its name and unit exactly
- **Attributes are low-cardinality** — an outcome, a trigger source, an error type. **Never a user,
  request or message ID.** No per-metric charge does not make cardinality free: every distinct
  combination is a series that is ingested, stored and scanned by every query, and the endpoint
  refuses more than a million new series in ten minutes
- **Instruments are created once, at init**, from a meter named for the Lambda, and handed to the
  handler as dependencies — never created per invocation

## Flushing in Lambda

**The handler flushes the meter provider before it returns, on every invocation.** An execution
environment is frozen the moment the handler returns, so a periodic reader's timer does not run,
and it can be reclaimed without warning, taking whatever was not exported with it.

- Flush with the invocation's context, so the flush is bounded by the time remaining
- **A failed flush is logged at `WARN` and never returned.** A metrics outage must not fail the
  invocation, and through it retry business work that succeeded
- **The flush is not free.** It is one HTTPS request per invocation, added to the duration the
  caller waits for, and every one counts against the endpoint's 500 requests per second **for the
  whole account**. A Lambda whose invocation rate could take the account near that limit flushes
  at most once every few seconds per execution environment instead, accepting that the counts
  since an environment's last flush are lost when it is reclaimed — a decision recorded, with its
  reason, in the project's conventions file

AWS documents no metrics path for Lambda beyond this: its Lambda guidance covers traces and logs,
and the ADOT Lambda layer's metrics support is EMF. That is why the export is done in-process, by
the code below, rather than by a layer.

## Temporality

**Cumulative** — the OpenTelemetry SDK default — with a `service.instance.id` per execution
environment. Each environment then reports its own series of running totals, and
`sum by (service_name) (rate(…))` adds them up. Without the instance ID, concurrent environments
would report clashing totals for the same series, and every rate would be wrong.

**AWS's documentation does not say which temporalities the endpoint accepts or how it treats short-
lived series.** Cumulative is the choice any PromQL store understands. It has one known weakness:
a series' first data point carries no earlier value, and a PromQL store that does not use the
OTLP start time loses that first count from `increase()`. **Before relying on any Lambda's counters,
verify them in a non-production environment**: count every invocation in a counter, and compare its
`increase()` over an hour with Lambda's own `Invocations` metric for the same hour. If they
disagree, the temporality decision is reopened. Delta temporality would avoid the problem, and
should be revisited if AWS documents support for it.

## The `telemetry` Package (Go)

`main.go` builds the provider and the Lambda's instruments; the `Handler` holds both, and `handle`
flushes:

```go
cfg, err := config.LoadDefaultConfig(ctx)
// …
provider, err := telemetry.NewMeterProvider(ctx, cfg, "sqs-new-users", namespace, environment)
meter := provider.Meter("sqs-new-users")
```

```go
func (h *Handler) handle(ctx context.Context, event events.SQSEvent) (events.SQSEventResponse, error) {
	defer func() {
		if err := h.metrics.ForceFlush(ctx); err != nil {
			slog.WarnContext(ctx, "metrics flush failed", "step", "handler.go:handle:flush-metrics", "error", err)
		}
	}()
	// …
}
```

```go
package telemetry

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	"github.com/google/uuid"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
)

// NewMeterProvider builds the Lambda's MeterProvider: OTLP over HTTP to
// CloudWatch's OpenTelemetry metrics endpoint, signed with SigV4. The handler
// flushes it at the end of every invocation; the reader's timer is a backstop.
func NewMeterProvider(ctx context.Context, cfg aws.Config, service, namespace, environment string) (*sdkmetric.MeterProvider, error) {
	exporter, err := otlpmetrichttp.New(ctx,
		otlpmetrichttp.WithEndpointURL(fmt.Sprintf("https://monitoring.%s.amazonaws.com/v1/metrics", cfg.Region)),
		otlpmetrichttp.WithHTTPClient(&http.Client{
			Timeout:   5 * time.Second,
			Transport: &signingTransport{base: http.DefaultTransport, credentials: cfg.Credentials, region: cfg.Region, signer: v4.NewSigner()},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("creating OTLP metric exporter: %w", err)
	}
	res := resource.NewSchemaless(
		attribute.String("service.name", service),
		attribute.String("service.namespace", namespace),
		attribute.String("service.instance.id", uuid.NewString()),
		attribute.String("deployment.environment.name", environment),
	)
	reader := sdkmetric.NewPeriodicReader(exporter, sdkmetric.WithInterval(time.Hour))
	return sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader), sdkmetric.WithResource(res)), nil
}

// signingTransport signs each export request with SigV4 for the "monitoring"
// service, which is what CloudWatch's OTLP metrics endpoint authenticates.
type signingTransport struct {
	base        http.RoundTripper
	credentials aws.CredentialsProvider
	region      string
	signer      *v4.Signer
}

func (t *signingTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	var body []byte
	if req.Body != nil {
		var err error
		if body, err = io.ReadAll(req.Body); err != nil {
			return nil, fmt.Errorf("reading export body: %w", err)
		}
		_ = req.Body.Close()
	}
	signed := req.Clone(req.Context())
	signed.Body = io.NopCloser(bytes.NewReader(body))
	signed.ContentLength = int64(len(body))

	creds, err := t.credentials.Retrieve(req.Context())
	if err != nil {
		return nil, fmt.Errorf("retrieving credentials: %w", err)
	}
	sum := sha256.Sum256(body)
	if err := t.signer.SignHTTP(req.Context(), creds, signed, hex.EncodeToString(sum[:]), "monitoring", t.region, time.Now()); err != nil {
		return nil, fmt.Errorf("signing export request: %w", err)
	}
	return t.base.RoundTrip(signed)
}
```

- **The signing happens in the transport**, after the exporter has built and encoded the request,
  because SigV4 signs a hash of the exact body sent. Anything that changes the body afterwards
  invalidates the signature
- **`aws.Config.Credentials` is already a caching provider**, so retrieving credentials per export
  costs nothing after the first
- Like the `logging` package, this is identical in every Lambda, and a strong candidate for a
  registered shared library

## Testing

- **Assert recorded metrics with an in-memory reader** — `sdkmetric.NewManualReader()` in Go,
  `InMemoryMetricExporter` in Node: build a provider on it, run the
  handler, collect, and assert on the data points. A metric is part of a Lambda's behaviour, and an
  untested one quietly stops being emitted
- **Test the signing against a local server**: point the exporter at an `httptest` server (or a
  `node:http` one), flush, and assert the `Authorization` header names the region and the
  `monitoring` service. That pins the one part of the exporter that is ours
