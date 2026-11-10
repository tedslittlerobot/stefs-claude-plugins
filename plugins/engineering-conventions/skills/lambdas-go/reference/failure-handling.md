# Failure Handling

Nothing in this file was in the `prototype-conventions` skill it was copied from. A prototype can
let a failed event vanish and a duplicate one run twice; a production system finds out about both
from its users. The rules are language-agnostic, and the `lambdas-node` skill defers to this file.

## Context and Deadlines

**`handle` takes `ctx context.Context` as its first parameter, and every function that does I/O
takes it too** — down through the sub-packages to the SDK call, `db.QueryContext`/`ExecContext`
and `http.NewRequestWithContext`.

```go
func (h *Handler) handle(ctx context.Context, event events.SQSEvent) (events.SQSEventResponse, error)
```

The context carries the invocation's deadline. A call made without it does not know the Lambda is
about to be timed out, so it runs on, and the work it was doing is cut off at an arbitrary point
instead of failing cleanly. It also carries the request and trace IDs the logger reads — see
`observability.md`.

When work must stop **before** the hard timeout — to report a partial batch, or log what was left
undone — derive a context with a margin:

```go
deadline, _ := ctx.Deadline()
ctx, cancel := context.WithDeadline(ctx, deadline.Add(-2*time.Second))
defer cancel()
```

## How Each Trigger Retries

Who retries a failure, and how often, depends entirely on how the Lambda was invoked — so the
handler's job differs by trigger:

| Invocation | Triggers | On error | The handler's job |
| --- | --- | --- | --- |
| **Synchronous** | `api-`, `api-socket-`, `alb-`, `url-`, `cognito-`, `aurora-` (`lambda_sync`), `invoke-` | **No retry by Lambda.** The caller gets the error | Map every error onto a deliberate response; never leak an internal error message to the caller |
| **Asynchronous** | `s3-`, `sns-`, `bus-`, `schedule-`, `email-`, `iot-`, `alarm-`, `logs-`, `aurora-` (`lambda_async`), `lambda-` | Lambda retries twice by default, then sends the event to the on-failure destination or dead-letter queue — **if there is one** | Return an error for anything worth retrying; be idempotent |
| **Event source mapping, queue** | `sqs-`, `mq-` | The message becomes visible again and is redelivered until the queue's `maxReceiveCount`, then moves to the redrive dead-letter queue | Report partial batch failures; be idempotent |
| **Event source mapping, stream** | `dynamo-`, `kinesis-`, `kafka-`, `docdb-` | The batch is retried **in order, blocking the shard**, until it succeeds or the records expire — unless the mapping sets a retry limit, bisects on error, and has an on-failure destination | Report partial batch failures; be idempotent; never let one record stall the shard for days |

`pipe-` and `secrets-` follow their caller's rules: an EventBridge Pipe retries per its own
configuration, and Secrets Manager retries a failed rotation step.

## Idempotency

**Every Lambda that is not invoked synchronously must produce the same result when it receives the
same event twice.** Delivery is at least once for every row of the table above except the first,
and duplicates are routine — a retry after a timeout whose work had in fact completed is the
commonest.

1. **Pick the idempotency key from the event**, not from when it arrived: the SQS `messageId`, the
   EventBridge event `id`, the S3 object key plus its `sequencer`, the stream record's sequence
   number. Record it in `schema.md`
2. **Prefer writes that are idempotent by construction** — an upsert keyed on a natural identifier,
   a conditional write (`attribute_not_exists`, `INSERT … ON DUPLICATE KEY UPDATE` that changes
   nothing the second time), setting a state rather than incrementing a counter
3. **Otherwise record the key** — a conditional insert into an idempotency table, in the **same
   transaction** as the effect where the effect is a database write, so the two cannot disagree
4. **An effect outside any transaction** — sending an email, calling a third party — cannot be made
   exactly-once from inside the Lambda. Pass the key on where the far side accepts one (an
   idempotency-key header), and otherwise say in the README which duplicate the system tolerates

## Partial Batch Responses

A batch handler for SQS, Kinesis or DynamoDB Streams **returns the records that failed** rather
than failing the whole invocation. The event source mapping must have `ReportBatchItemFailures` in
its `function_response_types`, or the response is ignored and the whole batch is treated as
succeeded.

```go
func (h *Handler) handle(ctx context.Context, event events.SQSEvent) (events.SQSEventResponse, error) {
	var failures []events.SQSBatchItemFailure
	for _, msg := range event.Records {
		if err := h.process(ctx, msg); err != nil {
			slog.ErrorContext(ctx, "message failed", "step", "handler.go:handle:process", "message_id", msg.MessageId, "error", err)
			failures = append(failures, events.SQSBatchItemFailure{ItemIdentifier: msg.MessageId})
		}
	}
	return events.SQSEventResponse{BatchItemFailures: failures}, nil
}
```

- **SQS**: the identifier is the `messageId`; only the failed messages are redelivered
- **Streams** (`events.KinesisEventResponse`, `events.DynamoDBEventResponse`): the identifier is the
  record's sequence number, and processing **stops at the first failure**, because everything after
  it is retried anyway to keep order. Report the first failure and return
- Returning an `error` from the handler still fails the whole batch — keep that for a failure that
  genuinely affects every record, such as the database being unreachable

## Where Failures Land

**Every asynchronous or event-source Lambda has a destination for events it finally gives up on**:

| Invocation | Destination |
| --- | --- |
| Asynchronous | An on-failure destination (SQS, SNS, EventBridge or another Lambda — a `lambda-` one), or a dead-letter queue |
| SQS | A redrive policy to a dead-letter queue on the source queue |
| Stream | A retry limit, `bisect_batch_on_function_error`, and an on-failure destination on the mapping |

Every one of those destinations is **alarmed** — see `observability.md`. A dead-letter queue nobody
watches is an event lost slowly instead of quickly.

**Separate permanent failures from transient ones.** An event that fails validation will fail
identically on every retry. Log it at `ERROR` with its identifier and send it to the failure
destination as fast as the trigger allows; spend the retries on the failures that might succeed
next time.

## Timeouts

- Set the function's timeout from what it does, not to the maximum. A timeout is the only bound on
  a hung dependency, and a fifteen-minute timeout on a two-second job is fifteen minutes of
  billed waiting
- **An SQS source queue's visibility timeout is at least six times the function's timeout** — AWS's
  own guidance. Shorter, and a message still being processed becomes visible and is delivered a
  second time
- A synchronous Lambda's timeout sits below its caller's: API Gateway gives up at 29 seconds by
  default, and Cognito waits five seconds for a trigger
