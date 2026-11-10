# Observability

Logs, metrics, traces and alarms. The key names, the alarm list and the reasoning are
language-agnostic, and the `lambdas-node` skill defers to this file for them.

## The `logging` Package

`main.go` configures the default logger once — `slog.SetDefault(logging.New("admin-create-user"))`
— and everything else logs through `slog.InfoContext(ctx, …)` and its siblings. The package is
small, generic and identical in every Lambda, which makes it a strong candidate for a registered
shared library (see `shared-libraries.md`); until the project registers one, each Lambda carries
its own `logging` sub-package.

```go
package logging

import (
	"context"
	"log/slog"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/lambdacontext"
)

// New returns the Lambda's logger: JSON on stdout, Powertools key names, the
// level taken from the function's application log level.
func New(service string) *slog.Logger {
	inner := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level:       levelFromEnv(),
		ReplaceAttr: renameKeys,
	})
	return slog.New(Handler{inner}).With("service", service)
}

// Handler adds the invocation's request and trace IDs to every record logged
// with a context, so no call site has to remember them.
type Handler struct{ slog.Handler }

func (h Handler) Handle(ctx context.Context, r slog.Record) error {
	if lc, ok := lambdacontext.FromContext(ctx); ok {
		r.AddAttrs(slog.String("function_request_id", lc.AwsRequestID))
	}
	if header, ok := ctx.Value("x-amzn-trace-id").(string); ok {
		if root := traceRoot(header); root != "" {
			r.AddAttrs(slog.String("xray_trace_id", root))
		}
	}
	return h.Handler.Handle(ctx, r)
}

// Without these two, a logger derived with .With() would drop the wrapper.
func (h Handler) WithAttrs(attrs []slog.Attr) slog.Handler { return Handler{h.Handler.WithAttrs(attrs)} }
func (h Handler) WithGroup(name string) slog.Handler       { return Handler{h.Handler.WithGroup(name)} }

func renameKeys(groups []string, a slog.Attr) slog.Attr {
	if len(groups) == 0 {
		switch a.Key {
		case slog.TimeKey:
			a.Key = "timestamp"
		case slog.MessageKey:
			a.Key = "message"
		}
	}
	return a
}

func levelFromEnv() slog.Level {
	switch os.Getenv("AWS_LAMBDA_LOG_LEVEL") {
	case "TRACE", "DEBUG":
		return slog.LevelDebug
	case "WARN":
		return slog.LevelWarn
	case "ERROR", "FATAL":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

func traceRoot(header string) string {
	for _, part := range strings.Split(header, ";") {
		if root, ok := strings.CutPrefix(part, "Root="); ok {
			return root
		}
	}
	return ""
}
```

- **The key names are Powertools for AWS Lambda's** (`timestamp`, `level`, `message`, `service`,
  `function_request_id`, `xray_trace_id`), because a Node Lambda logs through Powertools and both
  must answer the same query
- **`WithAttrs` and `WithGroup` must be overridden.** Embedding alone compiles, but a logger
  derived with `.With(…)` then returns the inner handler and silently stops adding the IDs
- **`aws-lambda-go` puts the trace header in the context under the string key `"x-amzn-trace-id"`.**
  Linters flag a string context key; this one is the library's, not ours to change
- Set the function's log format to **JSON** with an application log level. Lambda then sets
  `AWS_LAMBDA_LOG_LEVEL`, and filters by the `level` key itself as well

## Metrics

**What a Lambda does is a metric, not a log line someone has to count.** Emit business metrics —
users created, messages skipped, emails sent — in CloudWatch **Embedded Metric Format**: a JSON log
line CloudWatch turns into a metric with no API call and no extra latency.

```json
{"_aws":{"Timestamp":1794302043512,"CloudWatchMetrics":[{"Namespace":"<project namespace>","Dimensions":[["service"]],"Metrics":[{"Name":"users_created","Unit":"Count"}]}]},"service":"admin-create-user","users_created":1}
```

- In Go, a small `Metric` function in the `logging` package marshals that document and writes it to
  stdout; there is no official library to depend on, and the format is one JSON object
- **Dimensions are low-cardinality** — `service`, an outcome, a trigger source. Never a user,
  request or message ID: every distinct combination of dimension values is a separate billed custom metric
- The namespace and metric naming are project values, recorded in its conventions file

Lambda's own metrics — `Invocations`, `Errors`, `Throttles`, `Duration`, `ConcurrentExecutions`,
and `IteratorAge` for streams — come for free and are what most alarms watch.

## Tracing

Turn on **active tracing** for every function, and instrument the AWS SDK, outbound HTTP and SQL
with **OpenTelemetry** (the AWS Distro for OpenTelemetry), exporting to X-Ray. AWS is steering
instrumentation toward OpenTelemetry rather than its own X-Ray SDKs, so new code starts there. The
trace ID in every log line (`xray_trace_id`) is what joins a trace to its logs.

## Alarms

**A Lambda is not done until its alarms exist.** They are defined as infrastructure, but the
Lambda's author is the one who knows which apply:

| Lambda | Alarm on |
| --- | --- |
| Every one | `Errors` above zero (or above an agreed rate, for a high-volume function); `Throttles` above zero |
| Synchronous | `Duration` at a high percentile approaching the timeout |
| Asynchronous | Messages in its on-failure destination or dead-letter queue |
| `sqs-` | The source queue's `ApproximateAgeOfOldestMessage`; its dead-letter queue's `ApproximateNumberOfMessagesVisible` above zero |
| Stream (`dynamo-`, `kinesis-`, `kafka-`, `docdb-`) | `IteratorAge` — a stalled shard shows here first |

A dead-letter queue with messages in it means events have been given up on. That always pages
someone or opens a ticket, never only a dashboard.
