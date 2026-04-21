---
name: laws-of-software-engineering
description: >
  Apply the most actionable "laws" of software engineering — Conway's, Hyrum's, Gall's,
  Brooks's, Hofstadter's, Postel's, Goodhart's, CAP, the Fallacies of Distributed Computing,
  and others — as lenses for design, API, estimation, and review decisions. Use this skill
  when someone asks whether an architecture will survive growth, why a system feels coupled
  to its org, why an API consumer broke on a "compatible" change, why an estimate slipped,
  why a metric stopped working, whether to go big-bang or incremental, what will leak through
  an abstraction, or how to reason about distributed-system tradeoffs. Also trigger on vague
  "is this the right shape" / "will this scale" / "why did this go wrong" prompts where the
  user wants a named principle to anchor the argument. Do NOT use for style or framework
  questions, and prefer the `pragmatic-programmer` skill for DRY / Demeter / broken-windows
  /refactor-cadence questions — this skill covers the laws that sit *outside* that set.
---

# Laws of Software Engineering

A curated subset of the named "laws" that recur in real design and review decisions. Each
one is a **lens**, not a rule — useful when it names something you already sense but
couldn't articulate.

Source: <https://lawsofsoftwareengineering.com> (56 laws across 7 categories). This skill
covers ~17 of them chosen for how often they actually change a decision. The rest are
listed at the bottom for lookup.

The governing mindset: **cite a law only when it clarifies the specific situation.**
Laws are evidence, not arguments. If you find yourself reaching for one, ask whether it
actually applies or just sounds impressive.

---

## Architecture & APIs

### 1. Conway's Law
> *Organizations design systems that mirror their communication structure.*

Team boundaries become module boundaries whether you plan for it or not. A four-team
product will ship a four-service architecture even if three services would be better.

**Apply when:** a proposed architecture cuts across team lines in a way the org can't
sustain; or a weird seam in the code maps exactly to a reporting line. The *inverse
Conway maneuver* — restructure teams to produce the architecture you want — is often
cheaper than fighting the current shape.

**Don't apply when:** the coupling is genuinely technical, not organizational. Not every
ugly interface is Conway's fault.

### 2. Hyrum's Law
> *With enough users, every observable behavior of your system will be depended on by somebody.*

"Backwards compatible" means *compatible with every observable behavior*, not just the
documented contract. Ordering of iteration, timing, error messages, undocumented fields —
all become load-bearing once they're in the wild.

**Apply when:** reviewing a "safe" refactor to a widely-used API, library, or output
format. Ask: what observable property am I changing, and who might be relying on it?

**Practical form:** before changing public behavior, search for consumers; prefer adding
new shapes over mutating old ones; assume any output someone *could* parse, someone *has*.

### 3. Gall's Law
> *A complex system that works is invariably found to have evolved from a simple system that worked.*

You cannot design a complex working system from scratch. The big-bang rewrite that
replaces a working simple system with a complex one tends to fail. Grow the system; don't
forge it.

**Apply when:** someone proposes a greenfield rewrite of something that works, or a v1
architecture that tries to cover every future requirement. Push for the tracer-bullet
version first (see `pragmatic-programmer` #4).

**Don't apply when:** the existing system is fundamentally wrong (wrong data model, wrong
paradigm) and incremental evolution has been tried and stalled.

### 4. Law of Leaky Abstractions
> *All non-trivial abstractions, to some degree, are leaky.* (Joel Spolsky)

ORMs leak SQL. TCP leaks packet loss. Kubernetes leaks networking. Any abstraction that
hides complexity will, at some boundary condition, force the user to understand what it
was hiding.

**Apply when:** someone argues an abstraction will let engineers "not worry about" the
layer beneath. They will worry about it — probably at 3am. Budget time for learning the
layer under the abstraction, not just the abstraction itself.

### 5. Tesler's Law — Conservation of Complexity
> *Every application has an inherent amount of complexity that cannot be removed or hidden.*

You can push complexity around — into the UI, the backend, the config, the user — but you
can't delete it. "Making it simpler" often means *making it someone else's problem*.

**Apply when:** debating where complexity *should* live. The question is never "can we
eliminate this" but "who is best positioned to absorb it." Usually: put it where the
expertise is, not where it's easiest to implement.

### 6. CAP Theorem
> *A distributed data store cannot simultaneously provide more than two of: Consistency,
> Availability, Partition tolerance.*

In a real network, partitions happen, so you're always trading consistency against
availability *during a partition*. Most systems land on some flavor of "eventual
consistency" — which means the app needs to tolerate stale reads.

**Apply when:** reviewing a design that assumes strong consistency across services, or
when an outage postmortem blames "the network" for a consistency bug. The bug isn't the
network; it's designing as if partitions wouldn't happen.

### 7. Fallacies of Distributed Computing
> Eight assumptions that are false but feel true:
> 1. The network is reliable
> 2. Latency is zero
> 3. Bandwidth is infinite
> 4. The network is secure
> 5. Topology doesn't change
> 6. There is one administrator
> 7. Transport cost is zero
> 8. The network is homogeneous

**Apply when:** a design treats a remote call like a local one — no retries, no timeouts,
no idempotency, no awareness that the call costs money and time. Every RPC needs at least
a timeout, a retry policy, and an answer to "what happens if this returns twice."

### 8. Postel's Law (Robustness Principle)
> *Be conservative in what you send, liberal in what you accept.*

Originally good API advice; now partially discredited because "liberal acceptance" is how
Hyrum's Law bites you — every quirk you tolerate becomes a de-facto contract. Modern
reading: **be strict on input at trust boundaries, be precise on output, and reject
malformed data early**. "Liberal" meant forgiving of version skew, not of malformed input.

**Apply when:** designing an API or parser. Decide explicitly what you accept; don't just
accept whatever happens to parse.

### 9. Second-System Effect
> *The second system an engineer designs is the most dangerous — bloated with every feature
> they couldn't fit in the first.* (Fred Brooks)

The successful v1 earned its scope through discipline. The v2 discards the discipline and
tries to solve every edge case the v1 punted on.

**Apply when:** someone proposes a rewrite whose scope is "v1 + everything we learned."
Most of what you "learned" from v1 is best applied *to v1*. Push back on feature bundles
that grew during the rewrite.

---

## Planning & Estimation

### 10. Brooks's Law
> *Adding manpower to a late software project makes it later.*

New people need ramp-up, which pulls the productive people into mentoring. The
communication graph also grows quadratically. On a schedule-stressed project, adding a
person usually subtracts capacity for weeks before adding it.

**Apply when:** someone wants to rescue a slipping project by throwing bodies at it. The
honest options are: cut scope, extend the date, or accept the slip — not "add engineers."

### 11. Hofstadter's Law
> *It always takes longer than you expect, even when you take into account Hofstadter's Law.*

Estimates are systematically optimistic. Even estimates that correct for this are
optimistic. Plan for it; don't promise around it.

**Apply when:** reviewing a plan with no buffer, or an estimate the user seems emotionally
committed to. Ask what the plan looks like if this takes 2x.

### 12. The Ninety-Ninety Rule
> *The first 90% of the code accounts for the first 90% of the development time. The
> remaining 10% accounts for the other 90%.*

"Feature complete" is the point where the interesting work begins: error paths, edge
cases, operational hardening, the long tail of real-world inputs. Schedules that treat
"feature complete" as "nearly done" consistently miss.

**Apply when:** someone says "we're almost done." Ask what still has to happen between
"demo works" and "production-ready" — the answer is usually a lot.

### 13. Goodhart's Law
> *When a measure becomes a target, it ceases to be a good measure.*

Any metric attached to incentives will be gamed. Measure code coverage → tests that cover
without asserting. Measure tickets closed → ticket-splitting. Measure lines of code →
exactly what you'd expect.

**Apply when:** proposing a metric as a goal. Separate *measures you watch* from *targets
you commit to*, and be very careful about promoting one to the other.

### 14. Parkinson's Law
> *Work expands to fill the time available for its completion.*

A two-week task given four weeks takes four weeks — spent polishing, reconsidering, and
adding nice-to-haves. Shorter honest deadlines often ship more.

**Apply when:** scoping a task where "do it right" has no natural stop. Give it a budget
and a definition of done; otherwise it eats the calendar.

---

## Quality & Debugging

### 15. Kernighan's Law
> *Debugging is twice as hard as writing the code in the first place. Therefore, if you
> write the code as cleverly as possible, you are — by definition — not smart enough to
> debug it.*

If you wrote code at your intellectual limit, you have no headroom left to fix it when it
breaks. Write code noticeably *simpler* than the hardest you could write, so the debugging
version of you can follow it.

**Apply when:** reviewing clever one-liners, deeply generic abstractions, or any code the
author describes with pride. The question isn't "is this correct now" — it's "can the
on-call engineer at 2am figure out why this is wrong."

### 16. Linus's Law
> *Given enough eyeballs, all bugs are shallow.*

Mostly used to justify open source, but the operational form is: **the probability a bug
survives is inversely related to how many people have seriously looked at that code**.
Unreviewed code hides bugs better than reviewed code.

**Apply when:** deciding whether a change needs a second reviewer, or why a critical path
keeps producing incidents (usually: one person wrote it, nobody reads it).

---

## Scale & Performance

### 17. Amdahl's Law
> *The overall speedup from parallelizing a task is limited by the fraction of the task
> that cannot be parallelized.*

If 20% of your workload is serial, the absolute best speedup from infinite parallelism is
5x. Past a point, more cores / workers / machines add nothing.

**Apply when:** someone proposes scaling out to fix a performance problem. Ask what
fraction of the work is actually parallel, and what the serial bottleneck is. Usually the
serial part — a lock, a shared counter, a DB write — is the real fix.

---

## Design Heuristics

### 18. Principle of Least Astonishment
> *A component should behave in a way that most users will expect it to behave.*

Surprise is a cost. Cleverness that makes your API return `None` where a sibling returns
`[]` forces every caller to remember the exception. Consistency beats local optimization.

**Apply when:** naming a function, choosing a return type, defining an error, or picking a
default. The question is not "what's most elegant here" but "what will the reader assume
without reading the docs."

### 19. KISS — Keep It Simple
> *Systems should be as simple as possible — but not simpler.*

Complexity should be earned. Each layer, each framework, each configuration knob should
justify itself against the cost of understanding it. "Could this be a function instead of
a class / a class instead of a service / a service instead of a framework?"

**Apply when:** reviewing architecture that feels heavier than the problem. Good prompt:
"what's the simplest thing that could possibly work, and what's specifically missing from
that version?"

---

## Judgment & Decisions

### 20. Hanlon's Razor
> *Never attribute to malice that which is adequately explained by stupidity* — or, in
> engineering terms, *by a tired engineer, a missing doc, or a forgotten edge case*.

The weird behavior is almost never sabotage. The obnoxious API decision is almost never
intentional user-hostility. Debug and discuss as if everyone meant well; you'll be right
most of the time and kinder when you're wrong.

**Apply when:** a code review, incident, or interface-with-another-team is starting to
feel adversarial. Reframe to "what did they know when they made this choice."

### 21. Pareto Principle (80/20)
> *Roughly 80% of the effects come from 20% of the causes.*

A small fraction of bugs cause most of the pages; a small fraction of endpoints serve most
of the traffic; a small fraction of files hold most of the risk. Find the 20% before
optimizing the 80%.

**Apply when:** prioritizing — performance work, bug triage, refactor scope. Measure
before deciding where to spend effort.

### 22. Amara's Law
> *We overestimate the effect of a technology in the short run and underestimate it in the
> long run.*

The hype cycle is real. The thing everyone's breathless about this quarter will mostly
disappoint in a year and reshape the industry in ten. Don't rewrite for it now; don't
dismiss it either.

**Apply when:** someone proposes adopting — or banning — a new tool/framework/paradigm
based on its current hype or backlash. Ask what decision you'd make if you ignored the
last 12 months of discourse.

---

## How to Use This Skill

When the user's question has an obvious named law attached, **lead with the situation,
cite the law as supporting evidence, and propose a concrete action**. Don't open with
"Hyrum's Law states..." — open with what's actually going wrong.

### Flow
1. Read the situation. Identify at most **one or two** laws that genuinely apply.
2. Explain the specific smell or failure mode in the user's case.
3. Cite the law by name as a compact way to close the argument.
4. Propose a next step — a design change, a test, a conversation to have.

### Common presentations → likely law

| User says | Reach for |
|---|---|
| "We're rewriting it from scratch" | #3 Gall, #9 Second-System |
| "It's a minor change, should be backwards compatible" | #2 Hyrum |
| "This team keeps colliding with that team on the API" | #1 Conway |
| "The ORM / framework should handle this" | #4 Leaky Abstractions |
| "Let's move the complexity into the client / config / infra" | #5 Tesler |
| "We'll keep it consistent across regions" | #6 CAP, #7 Fallacies |
| "We'll just retry on failure" | #7 Fallacies (idempotency, timeouts) |
| "Let's just accept whatever comes in" | #8 Postel (strict at the boundary) |
| "Add more engineers, we're behind" | #10 Brooks |
| "Our estimate was off by 3x" | #11 Hofstadter, #12 Ninety-Ninety |
| "The team's coverage number keeps rising but bugs don't fall" | #13 Goodhart |
| "This two-day task took two weeks of polishing" | #14 Parkinson |
| "This code is too clever to debug" | #15 Kernighan |
| "This one file produces all our incidents" | #16 Linus, #21 Pareto |
| "We're adding more workers but it's not getting faster" | #17 Amdahl |
| "This API surprised me" | #18 Least Astonishment |
| "This architecture feels too heavy" | #19 KISS |
| "They did this on purpose to annoy us" | #20 Hanlon |
| "Everyone says we must adopt X right now" | #22 Amara |

### What to push back on
- **Law-dropping as argument.** Citing Hyrum's Law doesn't make a change unsafe; showing
  a likely consumer does. The law is the label, not the evidence.
- **Brooks's Law as an excuse to stop hiring.** It applies to *late projects*, not all
  staffing.
- **CAP as an excuse for sloppy consistency semantics.** You still have to decide what
  happens during a partition — CAP just says you can't dodge the question.
- **"It's just Conway's Law" as resignation.** Sometimes the answer *is* to restructure
  the teams.

### When to skip this skill
- The question is about a specific bug, syntax, or framework API — no law helps.
- The situation is covered better by `pragmatic-programmer` (DRY, Demeter, broken
  windows, refactor cadence, crash-early, design-by-contract).
- The user wants a concrete implementation, not a principled review.

### Companion skills
- `pragmatic-programmer` — overlapping territory; prefer it for design-level principles
  (DRY, orthogonality, reversibility, Demeter). This skill is the broader, more
  situational cousin.
- `code-review-author` — when your law-based critique becomes a PR comment, that skill
  covers how to present it without sounding smug.
- `diagnose-codebase` — run first when you're new to the repo; you can't apply Conway or
  Pareto without knowing the shape of the hurt.

---

## Appendix: the other laws (lookup only)

The source site has 56 laws. The ones not covered above — most either overlap with
`pragmatic-programmer`, are more cultural than actionable, or rarely change a decision —
are listed below for recognition. If a user names one, you can reason from first
principles using its one-line gloss.

**Teams:** Dunbar's Number (~150-person cognitive limit) · Ringelmann Effect (per-capita
output drops with group size) · Price's Law (√N do half the work) · Putt's Law (techies
don't manage; managers don't tech) · Peter Principle (promoted to incompetence) · Bus
Factor (how many losses before the project dies) · Dilbert Principle (promote the
incompetent out of harm's way).

**Architecture:** Law of Unintended Consequences (complex changes surprise) · Zawinski's
Law (every program expands until it reads email).

**Quality:** Murphy's Law (what can go wrong, will) · Broken Windows (covered in
`pragmatic-programmer`) · Technical Debt (everything slowing you down) · Testing Pyramid
(many unit, fewer integration, few UI) · Pesticide Paradox (repeated tests lose value) ·
Lehman's Laws (software must evolve) · Sturgeon's Law ("90% of everything is crap").

**Scale:** Gustafson's Law (parallelism helps more as problem size grows) · Metcalfe's
Law (network value ∝ n²).

**Design:** DRY, SOLID, Law of Demeter — covered in `pragmatic-programmer`.

**Decisions:** Dunning-Kruger (low skill, high confidence) · Occam's Razor (simplest
explanation usually wins) · Sunk Cost Fallacy (prior spend isn't a reason to continue) ·
The Map Is Not the Territory (the model is not the system) · Confirmation Bias (we see
what we expect) · Lindy Effect (longevity predicts longevity) · First Principles Thinking
(decompose, rebuild) · Inversion (reason from the failure backward) · Cunningham's Law
(post a wrong answer to get a right one).
