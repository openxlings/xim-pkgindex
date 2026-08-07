# `.agents/tools/` — the exit-code contract

Every script here reports through its exit code. There are four states, and a
caller has to handle all four:

```
0 = proven            the assertion was evaluated and holds
1 = broken            the assertion was evaluated and fails
2 = inconclusive      the check ran but cannot distinguish its cases
3 = could-not-run     this machine cannot exercise the check at all
```

**A caller MUST map 3 to "not run". It MUST NOT fold 3 into a pass**, and it
should not fold it into a failure either — a machine without an AMD GPU has not
found a bug in radeonsi.

## Why 3 exists

`skip()` in `graphics/selfcontained-check.sh` used to `exit 0`, and 0 is what
the caller reads as "S1-S4 pass". A machine without bwrap, or without a compiler
inside the subos, therefore printed

```
  ✓ empty-host self-containment      S1-S4 pass
```

for a check that ran nothing at all. Not a weaker pass, not a partial one: the
same green tick, the same words, from a script that exited before it built the
probe.

That is the exact bug class this tooling exists to catch, sitting inside the
tooling. Not-run and succeeded produced identical output — which is the whole
reason `verify-stack.sh` counts a third outcome, and the reason
`selfcontained-check.sh` runs a control container before it is willing to blame
the closure.

The reason it survived is worth keeping too: `verify-stack.sh` happens to probe
`bwrap` itself before calling the script, so the one skip anybody exercised was
shadowed by a caller-side guard. Every other skip path was live, and each of
them printed the tick.

## What each state means in practice

**2 and 3 are different questions.** 2 says the check ran and its result does
not separate the cases it was written to separate — `selfcontained-check.sh`
returns it when the *control* container fails, because then a sealed-container
failure proves nothing about self-containment and "S1: closure incomplete" would
name the wrong cause. 3 says nothing was measured, and says why: no bwrap, no
GPU, no compiler, no `/dev/dxg`, no payload to look at.

A check that cannot tell which it is should return 2. A wrong cause is worse
than no cause, because someone acts on it.

**1 is a claim about the subject, not about the environment.** A missing
`patchelf` is not a broken package. A missing subos is not an unsealed closure.
Build scripts follow the same split: 3 when the build never started (no subos,
no cmake, wrong architecture), 1 only when it started and broke — that is the
only status worth opening a log for.

An argument error (unknown flag, missing required option) sits outside the four:
nothing was checked and no verdict exists. Those exit 2, which is the safe
direction — a caller that follows the contract will not read it as a pass.

## Obligations on a caller

- Match on the code. `if script; then ok; else bad; fi` is the caller half of
  the same bug: it renders 2 and 3 as red. `verify-stack.sh` did exactly this to
  `verify-host-link.sh`, so a machine with no host compiler got a failing NVIDIA
  cell for a probe that was never built.
- Pass the child's code through rather than rewriting it. `|| return 1` in a
  driver loop erases the distinction the child went to the trouble of making.
- Carry the reason, not just the state. `verify-stack.sh`'s `na()` requires one,
  because "not applicable here" with no reason is indistinguishable from "nobody
  implemented it".
- Never let an absent tool answer the question. `patchelf --print-rpath` on a
  machine with no patchelf prints nothing, and "no host directories on the
  RPATH" is what nothing looks like. Probe for the tool; route to not-run.

## Reporting coverage

`verify-stack.sh` is the union point: it runs the whole matrix on one machine
and marks every cell it could not exercise. No single machine covers the matrix,
so the not-run cells are a recruitment list rather than an embarrassment. See
`graphics/collect-matrix.md` for what to run and where to send it.
