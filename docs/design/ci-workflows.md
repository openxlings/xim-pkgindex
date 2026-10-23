**English** | [简体中文](../zh/design/ci-workflows.md)

# CI workflow architecture

`CI` (`.github/workflows/ci.yml`) is the PR validation entry point. It also
validates main before publication. Feature-branch pushes do not run a second
copy of PR validation. Standalone manual, scheduled and protected publication
entry points retain their separate lifecycles.

## Plan before allocating runners

`ci-plan.py` compares explicit base/head commits and writes `ci-plan.json` and
a job summary. New, deleted and renamed recipes are included. Runtime-only
comparison uses the pinned updater's structural signature; opaque descriptors
fall back to testing rather than silently disappearing. Metadata-only edits
still receive static, registration, site and candidate-declaration checks.

The planner follows `xim.pkgindex.*` imports through shared modules and then
reverse package references using both source trees. It passes that expanded
file set to consumer fixtures. Literal coordinates in legacy dependency
expressions are deliberately conservative: an extra consumer is preferable to
missing a dependency. Dynamically computed platform tables fall back to the
existing platform readers rather than claiming unsupported precision.

Platform lifecycle jobs only exist when there are files to install. Their
native hosts remain Linux/Windows x86_64 and Apple Silicon macOS; automatic
upgrade candidates retain their explicit native platform/architecture matrix.
This change does not claim that an x86_64 install validates an ARM64 payload.

`.github/ci-profiles.json` owns routing. It lists each reusable workflow's own
file and local executors as well as the recipes it consumes. Routing changes
revalidate the profiles. Workflow execution remains in the existing files
with `workflow_call`: emulator, SDK, native-addon, GUI, bare-metal and Luban
acceptance criteria are retained. The resource builders and periodic sweep
are reusable as well as retaining their explicit manual/scheduled entry points.

Framework changes additionally install Eden's desktop and Android data
packages on the native desktop hosts and run its real CLI/APK smoke. This
small canary verifies actual payloads, routing and removal. The ncurses
closure regression is selected for relevant runtime changes and framework
changes, rather than appended to every unrelated package PR.

## One required result

The `required` job always runs and checks the plan's expected job ledger.
Failure or cancellation is an error; a planned job that is skipped or missing
is also an error. An intentionally unselected job may skip. A failed plan
cannot produce a passing result. The PR entry has no path filter, so even a
documentation-only PR produces the same required result.

Repository administrators should require the GitHub Actions `required` status
in the main ruleset after this workflow first passes. Keep the existing review,
signature and history rules. Branch rules are repository settings, not YAML.

Bot proposals explicitly dispatch this same entry with both base and expected
head SHA. If the branch moves before execution, validation fails. Candidate
validation is read-only; discovery and proposal creation stay in the scheduled
updater with their separate write permissions. No PR can run a publication step.

## Setup, resources and publication

The composite `setup-xlings` action shares the bootstrap used by platform
lifecycle, minimum-client registration and Eden smoke. Explicit client versions
preserve existing compatibility coverage rather than silently changing the
minimum supported client as part of this scheduling migration.

Resource builds filter `.github/res-build-matrix.json` in a plan job before
expanding the matrix; `only=sample-music` creates one build runner, not 64.
Toolchain smoke similarly selects each affected compiler on its relevant
platforms; GCC changes do not allocate a macOS LLVM-baseline runner.

Index, Pages and resource-mirror publication listen to successful main `CI`
push runs and check out the triggering run's exact SHA, rather than assuming
whatever main points at later was tested. Index publication also watches the
artifact builder/pointer publisher via its scope check. Scheduled and explicit
manual repair remain available. Main/sub-index pointer writes and rolling
backup are serialized; in-progress publication is not cancelled like stale PR
validation. Publication and validation use separate permission boundaries.

Only download/build artifacts with explicit content identities should be cached
in future. This migration deliberately does not introduce a mutable whole-home
cache that could bypass runtime-binding or installation regression checks.

## Maintenance

Run the scheduling/gate regression suite with:

```sh
python3 -m pytest tests/test_ci_architecture.py tests/test_autoupdate_dispatch.py -q
```

Run actionlint before changing workflow expressions. Regression fixtures cover
shared import/dependency expansion, deletion/rename, metadata-only scheduling,
platform selection, complete PR comparison, planned-job failure/skip handling,
resource filtering, compiler selection and source-pinned publication. Existing
static/isolation/index and specialized integration checks remain the executable
acceptance criteria.

Expired native Actions artifacts are transport failures, not permission to
change toolchain inputs. The ARM64 reuse path may recover only the existing
admitted archive hashes from immutable releases, after source-run, ancestry and
builder validation; glibc ledger/mirror checks and fresh native admission still
run. Recovery records its transport provenance. Scheduled/manual index or Pages
publication also checks successful main CI for its exact source SHA.
