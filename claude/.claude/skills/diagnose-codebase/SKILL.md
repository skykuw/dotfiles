---
name: diagnose-codebase
description: >
  Run a handful of git commands to diagnose a codebase *before* reading its code — surface
  high-risk files, bug hotspots, bus-factor risk, project momentum, and deployment stability.
  Use this skill when someone asks how to get oriented in an unfamiliar repo, where to start
  reading, what's risky to change, where bugs cluster, who knows this code, whether a project
  is healthy or dying, or how to assess a codebase they're inheriting, auditing, or joining.
  Also trigger on "onboarding to a new repo", "code archaeology", "where should I start", or
  "is this project still alive". Do NOT use for routine git workflow questions (commit, push,
  rebase) — this is diagnostic, not operational.
---

# Diagnose a Codebase Before Reading It

Before opening a single file, git history can tell you **where a codebase hurts**. Five commands
reveal risky files, bug hotspots, contributor dynamics, project momentum, and deployment
stability — usually in under a minute. Lead with these when someone is orienting to an
unfamiliar repo.

Source: Ally Piechowski, "5 Git Commands I Run Before Reading Any Code"
(https://piechowski.io/post/git-commands-before-reading-code/)

The golden rule: **let history guide where you look first.** Don't read a repo top-to-bottom.
Read the parts that churn, break, or nobody-but-one-person touches.

---

## The Five Commands

### 1. What changes the most (churn)
```bash
git log --format=format: --name-only --since="1 year ago" \
  | sort | uniq -c | sort -nr | head -20
```
The 20 most-modified files in the last year. High churn often means code everyone's afraid
to touch. A 2005 Microsoft Research study found churn predicts defects more reliably than
complexity metrics alone. **Cross-reference with command #3 — files on both lists are the
highest-risk code in the repo.**

### 2. Who built this (contributors)
```bash
git shortlog -sn --no-merges
```
Ranks contributors by commit count. Red flags:
- One person owns 60%+ of commits → **bus factor risk**
- Top contributor inactive 6+ months → **institutional knowledge gone**
- Many historical names, few recent ones → **team turnover**

Caveat: squash-merge workflows credit the merger, not the author. If the repo squashes,
pair this with `git log --format='%an' --no-merges | sort | uniq -c | sort -nr` and
interpret loosely.

### 3. Where bugs cluster
```bash
git log -i -E --grep="fix|bug|broken" --name-only --format='' \
  | sort | uniq -c | sort -nr | head -20
```
Files most often touched by bug-fix commits. Effectiveness depends on commit message
discipline — if the team uses conventional commits, tighten the regex (e.g. `^fix(\(|:)`).
If results look thin, the team may not label fixes in messages; fall back to PR labels or
issue trackers.

**Files on both #1 and #3 = "keep breaking, keep getting patched, never properly fixed."**
These are where you start.

### 4. Is this project accelerating or dying (momentum)
```bash
git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c
```
Commits per month across the repo's life. Read the shape:
- **Steady rhythm** → healthy
- **Sudden drop** → key person left, or project descoped
- **6–12 month decline** → losing momentum, possibly abandoned
- **Spikes then quiet** → batched release cadence, not necessarily unhealthy

### 5. How often is the team firefighting (stability)
```bash
git log --oneline --since="1 year ago" \
  | grep -iE 'revert|hotfix|emergency|rollback'
```
Frequent reverts/hotfixes = distrust in deploys, weak tests, or inadequate staging.
Zero results can mean genuine stability **or** that the team doesn't tag emergency commits —
check both interpretations before concluding.

---

## How to Use This Skill

When a user asks to get oriented in a repo, do **not** dump all five commands at them. Run
them yourself (via Bash) and present the **diagnosis**, not the raw output.

### Typical flow
1. Confirm the repo path and that it's a git repo.
2. Run commands #1 and #3 in parallel. Compute the **intersection** — those are the risky files.
3. Run #2, #4, #5 in parallel for context (team, momentum, stability).
4. Synthesize into a short report: "Start reading here. Watch out for X. This project looks Y."
5. Only then, open specific files.

### What to flag
| Signal | What it means | What to do |
|---|---|---|
| File in top-10 of both churn and bug lists | Highest-risk code | Read this first, suggest tests before changes |
| One author > 60% of commits | Bus factor risk | Note whose brain holds the context; ask them early |
| Top contributor inactive 6+ months | Knowledge loss | Expect undocumented decisions; budget discovery time |
| Commit frequency declining 6+ months | Project may be winding down | Ask the user if it's still actively developed |
| Frequent reverts/hotfixes | Deployment instability | Be cautious changing anything in hot paths |

### Common mistakes to avoid
- **Don't run these on a freshly cloned shallow repo** — `git clone --depth 1` gives you nothing useful. Check with `git rev-list --count HEAD` first; if it's small relative to the project's age, re-fetch with full history.
- **Don't over-trust command #3 on repos with bad commit hygiene.** If grep returns nothing, say so — don't claim "no bug hotspots."
- **Don't report raw command output to the user.** Synthesize. Raw `uniq -c` columns are noise; "these three files account for 40% of bug fixes" is signal.
- **Adjust time windows to the repo.** `--since="1 year ago"` is a default, not a law. For a 3-month-old project, use `"3 months ago"`. For a 10-year-old one, `"2 years ago"` may be more revealing.

### When to skip this skill
- Repo has < ~50 commits — history is too thin to diagnose.
- User already knows the repo well and is asking a targeted question.
- User is asking about a specific file or function, not the repo as a whole.
