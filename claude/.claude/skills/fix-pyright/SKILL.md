---
name: fix-pyright
description: Bulk-fix pyright errors across Python packages in a monorepo. Triages each error by rule name into tiers, then dispatches cost-tiered subagents — Haiku for mechanical fixes (missing imports, unused imports, missing type arguments, stale type:ignore comments), Sonnet for ambiguous type issues (return types, argument types, general type issues, incompatible overrides). Per-file verify-or-rollback via git plus a final whole-package sanity check. Use when the user invokes /fix-pyright, says "fix pyright errors in <package(s)>", "clean up pyright across these packages", or similar.
---

# fix-pyright

## When to invoke

- The user runs `/fix-pyright` with or without path arguments
- The user asks to fix, clean up, or clear pyright errors across one or more packages
- The user mentions a monorepo with pyright issues they want batched through

Do **not** invoke for a single file with one or two errors — that's faster done inline.

## Arguments

- `<paths...>` — package directories to process. If none given, auto-discover: every top-level subdirectory of the current git root that contains `pyproject.toml` or `pyrightconfig.json`.
- `--dry-run` — produce the triage report but make no edits and dispatch no subagents.
- `--max-parallel N` — override the per-batch parallelism cap. Default: 4.
- `--limit N` — process only the top-N files (by fixable-error count) per package. Report the remainder as "not processed this run; re-run to continue". Use this to cap run cost on the budget-capped work profile.
- `--include-tests` — do not skip test files. Off by default.

## Preflight

Before starting, confirm each tool is available:

- `pyright` on PATH — if missing, tell the user "`pyright` not found. Install with `npm install -g pyright` (or equivalent) and re-run." and abort.
- `jq` on PATH — bootstrap installs it, but verify. Abort with install hint if absent.
- `git` on PATH and `cwd` inside a working tree — rollback depends on both.

## Flow per package

### 1. Baseline + triage (one step)

Run `~/.claude/skills/fix-pyright/scripts/triage-report.sh <pkg>` (pass `--include-tests` iff the user asked for tests). The script runs pyright, applies `triage.json`, and emits one TSV row per error:

```
<tier>\t<file>\t<line>\t<col>\t<rule>\t<message>
```

`tier` is one of `mechanical`, `ambiguous`, `escalate`. The `skip` tier is dropped silently; unknown rules default to `escalate`. Test files are excluded unless `--include-tests` was passed.

Read the TSV into memory. Record the **per-file error count** (count of rows grouped by `file`) — needed later for verification. **Never load pyright's raw JSON into the orchestrator context** — the TSV is the only source of truth from this point on.

### 2. Plan

Group TSV rows by `(file, tier)`. Each group becomes one subagent dispatch. Print a compact plan (per-package, per-tier row counts — not a per-file listing). In `--dry-run` mode, stop here.

**If `--limit N` is set**: before planning, count **fixable** rows per file (mechanical + ambiguous only, excluding escalate). Sort files descending by that count, keep only the top N, and drop all TSV rows for files outside the top N. Carry the dropped files' counts into the final report as "deferred".

### 3. Dispatch mechanical tier (Haiku)

Use the Agent tool with `subagent_type: general-purpose` and `model: haiku`. Batch up to `--max-parallel` (default 4) at a time; launch each batch in a single assistant message with multiple tool uses so they run concurrently.

The mechanical prompt **does not include pyright messages** — the rule name plus line/col is enough for mechanical fixes. Format the error list compactly to keep prompt tokens minimal.

Prompt template for each mechanical subagent:

```
Fix the pyright errors listed below in <file>.

Rules for edits:
- Make the minimal edit to resolve each error.
- Do NOT add `# type: ignore` comments. If a fix requires one, skip that error and say so.
- Do NOT reformat unrelated code.
- Do NOT delete code as a fix unless pyright explicitly says it is unused AND you have verified (via Grep) that nothing else imports it.
- After editing, re-read the file and confirm the edits are in place. Do not run pyright — the orchestrator will verify.

Errors to fix (format `L<line>:<col> <rule>`):
  L3:12 reportUnusedImport
  L7:4 reportMissingImports
  ...

Reply with exactly two lines, no prose:
FIXED: <comma-separated line numbers you edited, or "none">
SKIPPED: <semicolon-separated line=reason pairs, or "none">
```

Example reply: `FIXED: 3,7,12` then `SKIPPED: 9=needs-cross-file-edit; 15=requires-type-ignore`.

### 4. Verify each batch

After a **batch** of subagents returns (wait for the whole batch, not each individual subagent — one pyright invocation per batch is much cheaper than one per file), feed `verify-batch.sh` a TSV on stdin with one `<baseline_count>\t<file>` row per file edited in the batch:

```
printf '%d\t%s\n' <baseline_1> <file_1> <baseline_2> <file_2> ... \
  | ~/.claude/skills/fix-pyright/scripts/verify-batch.sh
```

The script emits one TSV row per file: `<status>\t<file>` where status is `ok`, `regress`, or `tool-fail`.

- `ok` → keep edits. Parse the subagent's `SKIPPED:` line and append those lines to the escalate bucket, keyed by reason.
- `regress` → `git checkout HEAD -- <file>`, move that file's remaining errors to the `escalate` bucket, and log the rollback.
- `tool-fail` → abort the package.

If the script itself exits 2 (batch-level tooling failure), abort the package.

### 5. Re-baseline before the ambiguous tier

Before dispatching the ambiguous tier, re-run `triage-report.sh <pkg>` and read the fresh TSV. Mechanical fixes (missing imports especially) cascade-resolve many ambiguous errors; dispatching against the stale baseline would queue subagents for errors that no longer exist. The re-baseline cost is one pyright run; it typically saves several subagent dispatches.

Use the fresh TSV's ambiguous rows as the input to step 6. Use the fresh TSV's per-file error counts as the baseline for the ambiguous-tier batch verifies.

### 6. Dispatch ambiguous tier (Sonnet)

Same pattern as the mechanical tier, with `model: sonnet`.

Ambiguous subagents **do** need the pyright message — include it in the error list.

Prompt template is the same, except:

1. The rules paragraph adds: "These are ambiguous type issues. You may need to narrow a union, add a type guard, adjust a signature, or split a helper. Prefer the smallest semantically-correct fix. If the fix would require changes in other files, say so and skip — do NOT make cross-file edits."
2. The error list format is `L<line>:<col> <rule> — <message>`:
   ```
   L22:8 reportOptionalMemberAccess — "x" is possibly None
   ```
3. The reply format is unchanged (`FIXED:`/`SKIPPED:` two-line bounded).
4. Verify each batch with `verify-batch.sh` as in step 4.

### 7. Surface escalate bucket

Print a grouped list of escalated errors (file + rule + message) and ask the user how to proceed: fix one interactively, skip all, or retry with a stronger model for a specific file.

### 8. Whole-package sanity check

After all tiers finish, run `triage-report.sh <pkg>` once more over the whole package. Compare the new total row count (across all tiers) to the baseline.

- If new total ≤ baseline: report success.
- If new total > baseline: some fix introduced a cross-file regression. List the files whose row count increased. Ask the user: keep everything, rollback the regressing files, or hand off the remaining errors for manual fix.

### 9. Report

Emit a concise summary:

```
Package pkgs/foo
  baseline errors: 47
  fixed (mechanical, Haiku):  18
  fixed (ambiguous, Sonnet):  9
  rolled back:                2
  escalated to user:          4
  unchanged (skip list):      14
  final error count:          20  (Δ −27)
```

If `--limit N` was set and files were deferred, add a trailing line:

```
  deferred (--limit): 7 files, ~31 fixable errors — re-run to continue
```

One table per package.

## Safety rules

- **Never auto-commit.** The user reviews and stages manually.
- **Never add a fresh `# type: ignore`.** Only *remove* ones flagged by `reportUnnecessaryTypeIgnoreComment`.
- **Never delete code as a type fix** unless pyright flagged it unused AND you verified no other file imports it.
- **Never modify `tests/**`, `test_*.py`, `*_test.py`, `conftest.py`** by default. If the user explicitly asks to include tests, carry that flag through.
- **Rollback uses `git checkout HEAD -- <file>`.** If the file was already staged before the skill ran, warn the user — rollback would lose their staged edits. Check `git diff --cached --name-only` before starting and abort if any target file is staged.

## Cost posture

| Tier | Model | Where it runs |
|------|-------|---------------|
| Orchestrator | profile default (opus on personal, sonnet on work) | main thread |
| Mechanical | `haiku` via Agent tool override | subagent |
| Ambiguous | `sonnet` via Agent tool override | subagent |
| Escalate | profile default | orchestrator + user interaction |

Each subagent prompt is short and self-contained — prompt caching stays effective across a run, so the per-subagent cost is dominated by the file content it reads. Capping parallelism to 4 keeps the token burst predictable for rate-limited machines.

## Guardrails for the orchestrator

- **If the mechanical rollback rate exceeds 50% in a single package**, pause and surface the observation to the user before continuing. Something is off (wrong triage, malformed prompts, or odd codebase conventions).
- **If `triage-report.sh` exits 2** (pyright/jq missing, bad target, or pyright emitted non-JSON output), abort the package and report the error text to the user.
- **If a subagent returns "I need to edit another file to fix this,"** don't accept the cross-file edit — escalate instead. Single-file is the contract.
