---
name: code-review-author
description: >
  Best practices for developers submitting code for review — as the author, not the reviewer.
  Use this skill whenever someone asks how to prepare a PR or changelist, write a good pull
  request description, handle reviewer feedback, respond to code review comments, break up
  large PRs, or otherwise improve their code review process from the author's side. Also trigger
  when someone is frustrated with slow code reviews, conflicts during review, or getting poor
  feedback. Do NOT use for questions about how to *conduct* a review (that's the reviewer's
  perspective).
---

# Code Review Author Best Practices

When helping someone prepare or respond to a code review, your goal is to help them make their
reviewer's job easier — because that's what generates faster, higher-quality feedback and
reduces friction. The golden rule: **value your reviewer's time**.

Source: Michael Lynch, "How to Make Your Code Reviewer Fall in Love with You"
(https://mtlynch.io/code-review-love/)

---

## The 13 Techniques

### 1. Review your own code first
Before sending, read the diff yourself — in the same diff view your reviewer will use, not your editor. Imagine reading it for the first time. Take a break between writing and reviewing; morning eyes catch more than end-of-day eyes. Track your personal error patterns and create systems to prevent repeat mistakes.

### 2. Write a clear changelist description
Explain **what** the change achieves at a high level, and **why** you're making it. Don't assume context your reviewer already has — write for future readers too. A weak description forces your reviewer to reverse-engineer intent from code.

### 3. Automate the easy stuff
Never make a reviewer tell you about formatting, lint errors, or broken tests. All automated checks (CI, linters, formatters) should pass *before* requesting review. Add git pre-commit hooks if your team lacks CI.

### 4. Answer questions with the code itself
If a reviewer is confused, the answer isn't to explain it to them in a comment — it's to clarify the code itself so *everyone* who reads it understands. Prefer refactoring over code comments; comments are a fallback.

### 5. Narrowly scope changes
Each changelist should Do One Thing. Mixing unrelated fixes muddies the reviewer's mental model and slows review. Smaller, focused changelists can also be reviewed in parallel by different teammates.

### 6. Separate functional and non-functional changes
Never mix behavioral changes with whitespace reformatting or refactoring. If a file needs both refactoring and a behavior change, split them:
1. Add tests for existing behavior
2. Refactor (tests stay green — proves no behavior change)
3. Change behavior and update tests

### 7. Break up large changelists
When production code exceeds ~400 lines of changes, look for ways to split it. Ask: can dependencies be updated first in a separate CL? Can you ship half the feature now and the other half next? Smaller changelists get better feedback and merge faster.

### 8. Respond graciously to critiques
Don't take feedback personally. Treat every note as an objective observation about code, not your worth as a person. When a reviewer catches a bug, praise their thoroughness — it signals your changelist is clean enough that they could dig into real issues.

### 9. Be patient when your reviewer is wrong
Even mistaken feedback is a signal: if they misread the code, others might too. Instead of defending, look for ways to make the code *obviously* correct — rename, restructure, or add a clarifying comment.

### 10. Communicate your responses explicitly
Always make it clear who holds the baton. When you've addressed feedback, leave a changelist-level comment like "Updated, please take another look." For every note requiring action, reply explicitly ("Done" or explain why you're not acting on it). Never leave a reviewer wondering if you're still working.

### 11. Artfully solicit missing information
When feedback is vague (e.g., "this is confusing"), don't respond defensively. Ask:
> "What changes would be helpful?"

Or, better yet: guess the intent, make an improvement proactively, and show the revision. This signals openness and moves things forward.

### 12. Award all ties to your reviewer
When it's a matter of taste and you both have roughly equal evidence, defer to your reviewer. They have a fresh perspective on readability that you, as the author, can't fully replicate.

### 13. Minimize lag between rounds of review
Once you've sent code out, treat driving it to completion as your highest priority. Long delays force your reviewer to re-read everything and restore lost context — doubling their effort. Avoid letting changelists sit on the back burner.

---

## Coaching Guidance

When someone comes to you with a code review problem, first identify which of these 13 areas is the root cause. Common presentations:

| User's complaint | Likely technique to surface |
|---|---|
| "My reviewer keeps nitpicking style" | #3 — Automate formatting/linting |
| "My PRs take forever to get reviewed" | #5, #7, #13 — Scope/size/lag |
| "My reviewer misunderstood my code" | #4, #9 — Clarify in code, not comments |
| "My reviewer and I keep arguing" | #8, #12 — Graciousness, defer on ties |
| "I got vague feedback I can't act on" | #11 — Ask "What would be helpful?" |
| "My reviewer didn't catch important stuff" | #1, #6 — Self-review, separate changes |
| "Nobody knows context of this change" | #2 — Changelist description |

Be concrete. If someone shares a PR description, a code snippet, or a review thread, apply the relevant techniques directly rather than listing all 13. The goal is actionable, specific feedback.
