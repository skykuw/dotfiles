---
name: pragmatic-programmer
description: >
  Apply the most actionable principles from Andy Hunt and Dave Thomas's *The Pragmatic
  Programmer* to design and review decisions: DRY, orthogonality, reversibility, tracer
  bullets, fix broken windows, crash early, design by contract, Law of Demeter, programming
  by coincidence, and refactoring cadence. Use this skill when someone asks whether their
  code is well-designed, is this over-engineered, should I refactor now, how do I decouple
  this, is this DRY enough, is this brittle, why does this feel wrong, or is this the right
  abstraction. Also trigger on vague "make this better" / "review this design" prompts where
  the user wants principled pushback, not just surface polish. Do NOT use for style nits or
  framework-specific idioms — this is about engineering judgment.
---

# Pragmatic Programmer Principles

Andy Hunt and Dave Thomas's tips for making *good decisions* under real-world constraints.
Not all 100 tips are useful in every moment — this skill covers the ~12 that repeatedly
come up when designing, reviewing, or rescuing code.

Source: Andy Hunt & Dave Thomas, *The Pragmatic Programmer* (20th Anniversary Edition).

The governing mindset: **think about what you're doing while you're doing it.** Every tip
below is a lens, not a law.

---

## The Core Principles

### 1. DRY — Don't Repeat Yourself
> *Every piece of knowledge must have a single, unambiguous, authoritative representation within a system.*

DRY is about **knowledge**, not code shape. Two functions with identical bodies that
represent **different rules** aren't DRY violations — they just coincidentally look alike
today. Conversely, the same business rule encoded in three places (validation, DB constraint,
UI) **is** a violation even if the code is different.

**Apply when:** You're about to copy-paste, or you see a magic number / format / rule repeated.
**Don't apply when:** The similarity is coincidental. Premature abstraction is worse than duplication. Rule of three: wait for the third occurrence before extracting.

### 2. Orthogonality
Changes in one module shouldn't ripple into unrelated modules. Orthogonal systems are easier
to test, reuse, and change.

**Smell test:** "If I change requirement X, how many files do I touch?" If it's many and
they span unrelated concerns, coupling is too high.

### 3. Reversibility — There Are No Final Decisions
Architectures, vendors, and data stores all change. Design so today's choice isn't welded in.
Hide third-party APIs behind thin wrappers. Keep business logic independent of frameworks.

**Don't confuse with over-abstraction.** A wrapper with one caller is noise. Reversibility
means *making it possible to change*, not pre-building the change.

### 4. Tracer Bullets vs. Prototypes
- **Tracer bullet:** a minimal, end-to-end, *production-grade* slice that proves the full
  path works. You keep it and grow it.
- **Prototype:** a throwaway experiment to answer one question. You delete it.

**The mistake:** shipping a prototype. If code was written to learn, not to run, rewrite
before production.

### 5. Fix Broken Windows
Don't leave bad code, bad tests, or bad design decisions unrepaired. Rot accelerates — each
broken window signals that nobody cares, which makes the next shortcut feel normal.

**Practical form:** if you see a small defect while passing through, fix it or file it —
don't walk by.

### 6. Good-Enough Software
Quality is a requirement, like any other — traded off against time, scope, and cost. Ship
something real and iterate. **Perfection is the enemy of shipped.**

**Apply when:** you're gold-plating. Ask: "What's the cheapest version that solves the real
problem?"
**Don't apply when:** the cost of the bug is catastrophic (finance, safety, auth).

### 7. Crash Early — Dead Programs Tell No Lies
A program that crashes near the source of the fault is far easier to debug than one that
limps along producing corrupted data. Let it die at the first sign of impossibility.

**Practical form:** prefer `assert` / `panic` / early throws over silent fallbacks. Don't
catch exceptions you can't meaningfully handle.

### 8. Design by Contract
Every function has a contract: preconditions (what must be true to call it), postconditions
(what it guarantees on return), and invariants (what it never breaks). Make them explicit.

**Lightweight form in modern code:** type signatures + input validation at the boundary +
assertions for internal invariants.

### 9. Decouple — The Law of Demeter
A method should only talk to:
- itself
- its parameters
- objects it creates
- its direct components

**Smell:** `a.b().c().d()` — you're reaching through layers, coupling yourself to the full
object graph. One refactor changes everything. Replace with a method on `a` that returns
what you actually need.

### 10. Don't Program by Coincidence
If the code works but you can't explain *why*, you're relying on accident. Race conditions,
ordering assumptions, undefined-behavior quirks — they work until they don't, and then they
fail in production at 3am.

**The discipline:** before committing, articulate *why* this works. If "because it passed
the test" is the only answer, you haven't understood it yet.

### 11. Refactor When You See the Need, Not Later
Refactoring is not a separate phase. It's continuous. When you see code that's drifting from
its shape, fix it *now* while the context is fresh — not on a future sprint that never comes.

**Guardrails:** refactor behind green tests. Never mix a refactor with a behavior change
(see code-review-author skill, tip #6).

### 12. Make It Easy to Test
If code is hard to test, the design is wrong. Testability pressure is the single best force
for good architecture — it demands decoupling, clear contracts, and minimal hidden state.

**When you hit "this is hard to test":** don't reach for mocks. Ask what about the code's
shape makes it resist testing, and fix that.

---

## How to Use This Skill

When a user asks you to review or improve code through a "pragmatic" lens, don't recite all
twelve. **Diagnose first, then cite.**

### Flow
1. Read the code and identify **one or two** principles that actually apply.
2. Explain the specific smell in the user's code.
3. Cite the principle by name only as supporting evidence — not as the lead.
4. Propose a concrete fix, not a philosophical direction.

### Common presentations → likely principle

| User says | Reach for |
|---|---|
| "Feels over-engineered" | #1 (premature DRY), #3 (abstraction without reversibility need) |
| "Changing X breaks Y" | #2 orthogonality, #9 Demeter |
| "This is hard to test" | #12 testability, usually symptom of #2 or #9 |
| "It works but I don't know why" | #10 coincidence — stop and understand before shipping |
| "Should I fix this now or later?" | #5 broken windows (now, usually) vs. #6 good-enough |
| "Should I refactor?" | #11 — yes, now, behind tests |
| "Copy-pasted and now they've drifted" | #1 DRY, but only if same *knowledge* |
| "Wrapped in try/except and swallowing errors" | #7 crash early |
| "How do I make this flexible for the future" | #3 reversibility — but resist speculative generality |

### What to push back on
- **Premature abstraction dressed as DRY.** The rule-of-three exists for a reason.
- **Reversibility as an excuse for five layers of interfaces.** Wrappers need a caller.
- **"Defensive programming" that masks bugs.** See #7.
- **Refactoring scope creep.** Mixing a refactor with a feature is a code-review sin (see
  code-review-author skill). If the user wants to "clean up while I'm in here," bound it.

### When to skip this skill
- Style/formatting questions — that's a linter's job.
- Framework-specific questions (React state, Django ORM) — use framework docs.
- The user wants a specific fix, not a principle-led review.
- Code under ~20 lines — principles are for system shape, not snippets.

### Companion skills
- `diagnose-codebase` — run *before* this skill when you're new to a repo. You can't apply these principles without knowing where the repo hurts.
- `code-review-author` — when the output of pragmatic review becomes a PR, that skill covers how to present it.
