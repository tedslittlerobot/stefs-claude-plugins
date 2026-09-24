#!/bin/bash
#
# Hook driving the auto-summary-commit skill. Two modes, wired to two events:
#
#   pre    UserPromptSubmit — fingerprints the working tree before the turn runs.
#   stop   Stop            — fingerprints it again, and if this turn changed
#                            anything, blocks the stop once and tells the model
#                            to run the skill on exactly the paths it changed.
#
# The baseline is the whole point. Without it the hook can only ask "is the tree
# dirty", which is the wrong question: it fires on work that was already
# uncommitted when the session started, nags on every later turn once the user
# has declined, and would let `git add -A` sweep somebody else's edits into a
# commit described as this turn's work. With it, the hook answers "what did THIS
# turn change" and hands that list over.
#
# It never commits anything. Staging, the summary and the question are the
# skill's job; the hook only ensures the skill runs, on the right paths.
#
# Exit 0 with no output = say nothing, let the turn end.
# Exit 0 with JSON       = hookSpecificOutput.additionalContext is fed to the model
#                          and the conversation continues so it can act on it.
#
# additionalContext, not the top-level {"decision":"block","reason":...}: that is
# the legacy field, and Claude Code routes it through the blocking-error path, so
# every nudge was rendered to the user as "Stop hook error: ..." even though it
# worked. The Stop schema names additionalContext as "Feedback for the model".
#
# Dependencies: git, and bash builtins. Nothing else — a hook that dies on a thin
# PATH dies at the end of every single turn. jq is used only when it is present.

set -uo pipefail

MODE="${1:-stop}"
HOOK_INPUT=$(cat)

# --- read the fields we need, with or without jq -----------------------------

json_field() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | jq -r --arg k "$key" '.[$k] // ""' 2>/dev/null
  else
    # Good enough for the flat scalar fields of these payloads.
    printf '%s' "$HOOK_INPUT" |
      tr ',' '\n' |
      sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" |
      head -n 1
  fi
}

SESSION_ID=$(json_field session_id)
CWD=$(json_field cwd)
STOP_HOOK_ACTIVE=$(json_field stop_hook_active)

[ -n "$CWD" ] && [ -d "$CWD" ] && cd "$CWD" 2>/dev/null

# No session id means no per-session state we can trust: a shared fallback file
# would let one session's "don't commit" silence another's.
[ -z "$SESSION_ID" ] && exit 0

command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

STATE_DIR="${TMPDIR:-/tmp}"
STATE_DIR="${STATE_DIR%/}"
STATE_BASE="$STATE_DIR/claude-auto-summary-commit-$SESSION_ID"
PRE_FILE="$STATE_BASE.pre"
NUDGE_FILE="$STATE_BASE.nudged"
DEFER_FILE="$STATE_BASE.deferred"
PROMPT_FILE="$STATE_BASE.prompt"
TURN_FILE="$STATE_BASE.turnopen"
MARKER="$STATE_BASE.off"

# --- fingerprint the working tree --------------------------------------------
#
# One "<content hash><TAB><path>" line per path git would record. Content hashes,
# not status codes: a file that was already modified before the turn and modified
# again during it has the same status code both times, and comparing codes alone
# would file it under "not mine".
#
# --no-renames keeps one path per entry, -z removes git's quoting of odd names,
# and --untracked-files=all expands new directories to their files.

snapshot() {
  local entry path hash
  while IFS= read -r -d '' entry; do
    [ ${#entry} -lt 4 ] && continue
    path="${entry:3}"
    [ -z "$path" ] && continue
    if [ -f "$path" ] && [ ! -L "$path" ]; then
      hash=$(git hash-object -- "$path" 2>/dev/null) || hash="?"
    else
      # Deleted, or a symlink/special file we deliberately do not hash.
      hash="-"
    fi
    printf '%s\t%s\n' "$hash" "$path"
  done < <(git status --porcelain -z --no-renames --untracked-files=all 2>/dev/null)
}

# --- pre: record the baseline, say nothing -----------------------------------

if [ "$MODE" = "pre" ]; then
  # UserPromptSubmit stdout becomes model context, so this mode must stay silent.

  # Only the FIRST prompt of a turn moves the baseline. A message sent mid-turn
  # fires this event again, and re-snapshotting there would fold the work already
  # done into the baseline — quietly dropping it from the commit.
  if [ ! -f "$TURN_FILE" ]; then
    snapshot > "$PRE_FILE" 2>/dev/null
    # Start a fresh prompt record, unless work deferred by an earlier turn is
    # still outstanding: that turn's prompt belongs in the same commit as its
    # changes.
    [ -s "$DEFER_FILE" ] || : > "$PROMPT_FILE" 2>/dev/null
    touch "$TURN_FILE" 2>/dev/null
  fi

  # Record the prompt so the commit body can quote what was actually asked,
  # exactly, even after the turn's context has been compacted. jq only: the
  # fallback parser cannot survive the newlines and quoting of real prompt text,
  # and a mangled prompt in a commit is worse than none.
  if command -v jq >/dev/null 2>&1; then
    PROMPT_TEXT=$(printf '%s' "$HOOK_INPUT" | jq -r '.prompt // ""' 2>/dev/null)
    if [ -n "$PROMPT_TEXT" ]; then
      [ -s "$PROMPT_FILE" ] && printf '\n' >> "$PROMPT_FILE" 2>/dev/null
      printf '%s\n' "$PROMPT_TEXT" >> "$PROMPT_FILE" 2>/dev/null
    fi
  fi
  exit 0
fi

# --- stop: decide whether this turn produced a commit's worth of work ---------

# The turn is ending, so the next prompt starts a new one and takes a new
# baseline. Cleared before any early exit: every path below ends the turn.
rm -f "$TURN_FILE" 2>/dev/null

# Already blocked once in this stop cycle. Without this the hook blocks again
# after the skill has run — the tree is still dirty when the user declines, and
# the skill is right to leave it that way — and the turn can never end.
case "$STOP_HOOK_ACTIVE" in
  true|True|1) exit 0 ;;
esac

case "${AUTO_SUMMARY_COMMIT:-}" in
  0|off|no|false) exit 0 ;;
esac
[ -f "$MARKER" ] && exit 0

# Committing into a half-finished rebase or merge is not something the user can
# easily undo, so leave those alone entirely.
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || exit 0
for op in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG; do
  [ -e "$GIT_DIR/$op" ] && exit 0
done

CURRENT=$(snapshot)
[ -z "$CURRENT" ] && exit 0

# No baseline — the plugin was installed mid-session, or the pre hook did not
# run. We cannot tell this turn's work from what was already there, so we do not
# guess: staying quiet costs one missed commit, guessing costs a commit that
# claims to be this turn's work and is not.
[ -f "$PRE_FILE" ] || exit 0
PRE=$'\n'"$(cat "$PRE_FILE" 2>/dev/null)"$'\n'

# Lines present now but not in the baseline are this turn's doing: either a path
# that was clean before, or one whose content hash has moved since.
MINE=""
DIRTY_PATHS=""
COUNT=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="${line#*$'\t'}"
  DIRTY_PATHS="$DIRTY_PATHS${DIRTY_PATHS:+$'\n'}$path"
  case "$PRE" in
    *$'\n'"$line"$'\n'*) : ;;                     # unchanged since the baseline
    *) MINE="$MINE${MINE:+$'\n'}$path"
       COUNT=$((COUNT + 1)) ;;
  esac
done <<< "$CURRENT"

# This turn changed nothing git would record. Say nothing at all — deferred work
# from earlier turns is not a reason to interrupt a turn that did none of its own.
[ -z "$MINE" ] && exit 0

# Work the user put off rather than disowned ("not yet", "I'll do it myself") is
# still this session's to commit, so fold it back in — otherwise the eventual
# commit covers only the last turn's slice and silently leaves the rest behind.
# Anything since committed or reverted has dropped out of the dirty set already.
if [ -f "$DEFER_FILE" ]; then
  while IFS= read -r dpath; do
    [ -z "$dpath" ] && continue
    case $'\n'"$DIRTY_PATHS"$'\n' in
      *$'\n'"$dpath"$'\n'*) : ;;
      *) continue ;;                                # no longer dirty: done with
    esac
    case $'\n'"$MINE"$'\n' in
      *$'\n'"$dpath"$'\n'*) continue ;;           # already listed this turn
    esac
    MINE="$MINE${MINE:+$'\n'}$dpath"
    COUNT=$((COUNT + 1))
  done < "$DEFER_FILE"
fi

# Never raise the same tree twice. stop_hook_active is the documented guard, but
# it only covers the immediate continuation; this covers the rest of the session.
# If the user declined, the tree stays exactly as it was, so the fingerprint
# matches and the question is not asked again. Any real change alters it.
if [ -f "$NUDGE_FILE" ]; then
  LAST=$(cat "$NUDGE_FILE" 2>/dev/null)
  [ "$LAST" = "$CURRENT" ] && exit 0
fi
printf '%s' "$CURRENT" > "$NUDGE_FILE" 2>/dev/null

# Keep the instruction a sane size on a turn that touched hundreds of paths.
PATH_LIST="$MINE"
if [ "$COUNT" -gt 60 ]; then
  PATH_LIST=""
  n=0
  while IFS= read -r p; do
    n=$((n + 1))
    [ "$n" -gt 60 ] && break
    PATH_LIST="$PATH_LIST${PATH_LIST:+$'\n'}$p"
  done <<< "$MINE"
  PATH_LIST="$PATH_LIST"$'\n'"... and $((COUNT - 60)) more"
fi

read -r -d '' CONTEXT <<'EOF' || true
Uncommitted work from this session. Run the `auto-summary-commit` skill before
ending this turn and follow it exactly — including its rule for when to commit
straight away and when to ask the user first.

Stage only these paths — the list already excludes anything that was dirty
before the turn started, and includes work an earlier answer deferred (__COUNT__):
__PATHS__

State files:
  prompt:   __PROMPT__   (this turn's prompt, verbatim, for the commit body)
  deferred: __DEFER__
  off:      __MARKER__
EOF

CONTEXT="${CONTEXT//__MARKER__/$MARKER}"
CONTEXT="${CONTEXT//__DEFER__/$DEFER_FILE}"
CONTEXT="${CONTEXT//__PROMPT__/$PROMPT_FILE}"
CONTEXT="${CONTEXT//__COUNT__/$COUNT}"
CONTEXT="${CONTEXT//__PATHS__/$PATH_LIST}"

SYSMSG="auto-summary-commit: $COUNT uncommitted path(s) from this session"

if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg ctx "$CONTEXT" \
    --arg msg "$SYSMSG" \
    '{systemMessage: $msg,
      hookSpecificOutput: {hookEventName: "Stop", additionalContext: $ctx}}'
else
  # Hand-rolled JSON: escape backslashes and quotes, then newlines.
  ESCAPED=$(printf '%s' "$CONTEXT" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"%s"}}\n' \
    "$SYSMSG" "$ESCAPED"
fi

exit 0
