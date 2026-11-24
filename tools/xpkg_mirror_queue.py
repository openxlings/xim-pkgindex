#!/usr/bin/env python3
"""Plan, run and record the xlings-res mirror batch.

Used by .github/workflows/xpkg-mirror.yml (after a successful CI on main) and by
.github/workflows/mirror-precheck.yml (a dry run on pull requests). The policy is in
docs/13-ci-mirror-and-update.md; the maintainer procedure is in
.agents/skills/xlings-res-maintainer/SKILL.md.

  plan      packages to process: changed since the last successful run, plus the packages
            the tracking issue still lists as failing.
  run       materialize, verify and (unless --dry-run) mirror each planned package, a few at a
            time; one result file per package.
  precheck  for a pull request: materialize and verify the changed packages that declare
            ci = { mirror = true }; publish nothing.
  record    rewrite the failing list from the results and render the tracking issue body.

The tracking issue body is the only state: a hidden JSON block lists the failing packages.
There is one such issue, found by its label; it is never duplicated.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import re
import subprocess
import sys
from pathlib import Path

ISSUE_TITLE = "xlings-res mirror: packages that did not publish"
ISSUE_LABEL = "mirror-failed"
STATE_OPEN = "<!-- xlings-res-mirror-state"
STATE_CLOSE = "-->"
WORKERS = 2
# One package's materialize, verify or mirror step. A GitCode upload has its own,
# shorter timeout in xpkg_ci.py (GITCODE_UPLOAD_TIMEOUT) with one retry.
STEP_TIMEOUT = 3600
ERROR_LIMIT = 300
SECRET = re.compile(
    r"(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}"
    r"|x-access-token:[^@\s]+)"
)


def scrub(text: str) -> str:
    """One line, no tokens, bounded length: it is posted in a public issue."""
    text = SECRET.sub("<redacted>", " ".join(str(text).split()))
    return text if len(text) <= ERROR_LIMIT else text[: ERROR_LIMIT - 3] + "..."


def git(workspace: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(workspace), *args], text=True, capture_output=True,
                          check=True).stdout


def is_ancestor(workspace: Path, base: str, head: str) -> bool:
    done = subprocess.run(["git", "-C", str(workspace), "merge-base", "--is-ancestor", base, head],
                          capture_output=True)
    return done.returncode == 0


def changed_stems(workspace: Path, *rev: str) -> list[str]:
    names = git(workspace, "diff", "--name-only", *rev, "--", "pkgs/*/*.lua").splitlines()
    return sorted({Path(name).stem for name in names if name.strip()})


def plan_range(workspace: Path, base: str, head: str) -> tuple[str, ...]:
    """Since the last successful run; the first run (or an unknown base) looks one commit back."""
    if base and is_ancestor(workspace, base, head):
        return (base, head)
    return (f"{head}^", head)


def xpkg_ci(workspace: Path, *args: str, timeout: int = STEP_TIMEOUT) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(workspace / "tools" / "xpkg_ci.py"),
                           "--workspace", str(workspace), *args],
                          text=True, capture_output=True, timeout=timeout)


def declares_mirror(workspace: Path, package: str) -> bool:
    done = xpkg_ci(workspace, "inspect", "--only", package, timeout=300)
    if done.returncode != 0:
        return False
    rows = json.loads(done.stdout).get("packages") or []
    return bool(rows and rows[0].get("mirror"))


def read_pending(body: str) -> dict[str, dict]:
    match = re.search(re.escape(STATE_OPEN) + r"(.*?)" + re.escape(STATE_CLOSE), body or "", re.S)
    if not match:
        if STATE_OPEN in (body or ""):
            raise SystemExit("tracking issue state block is unterminated")
        return {}
    # A block that exists but cannot be read must stop the batch: treating it as empty
    # would drop every failure it lists and close the tracking issue.
    try:
        return dict(json.loads(match.group(1)).get("pending", {}))
    except (json.JSONDecodeError, AttributeError) as exc:
        raise SystemExit(f"tracking issue state block is not valid JSON: {exc}")


def current_state(path: str) -> tuple[int | None, str | None, dict[str, dict]]:
    """The tracking issue as `gh issue list --json number,state,body` printed it (or nothing)."""
    if not path or not Path(path).exists():
        return None, None, {}
    items = json.loads(Path(path).read_text(encoding="utf-8") or "[]")
    if not items:
        return None, None, {}
    item = items[0]
    return item["number"], item["state"], read_pending(item.get("body") or "")


def plan(workspace: Path, head: str, base: str, pending: dict[str, dict], only: str = "") -> dict:
    if only:
        if not declares_mirror(workspace, only):
            raise SystemExit(f"{only} does not declare ci = {{ mirror = true }}")
        return {"head": head, "packages": [only], "dropped": []}
    packages = [name for name in changed_stems(workspace, *plan_range(workspace, base, head))
                if declares_mirror(workspace, name)]
    dropped = []
    for name in sorted(pending):
        if name in packages:
            continue
        if declares_mirror(workspace, name):
            packages.append(name)
        else:
            dropped.append(name)
    return {"head": head, "packages": sorted(packages), "dropped": sorted(dropped)}


def run_one(workspace: Path, package: str, work: Path, dry_run: bool) -> dict:
    manifest = work / package / "manifest.json"
    steps = [("materialize", ["materialize", package, "--output", str(work / package)]),
             ("verify", ["verify", str(manifest)])]
    if not dry_run:
        steps.append(("mirror", ["mirror", str(manifest), "--execute"]))
    for step, args in steps:
        try:
            done = xpkg_ci(workspace, *args)
        except subprocess.TimeoutExpired:
            return {"package": package, "status": "failed", "step": step,
                    "error": f"timed out after {STEP_TIMEOUT}s"}
        if done.returncode != 0:
            lines = (done.stderr or done.stdout or "").strip().splitlines()
            return {"package": package, "status": "failed", "step": step,
                    "error": scrub(lines[-1] if lines else f"exit status {done.returncode}")}
    return {"package": package, "status": "ok", "step": steps[-1][0]}


def run_batch(workspace: Path, packages: list[str], work: Path, results: Path,
              dry_run: bool = False) -> list[dict]:
    work.mkdir(parents=True, exist_ok=True)
    results.mkdir(parents=True, exist_ok=True)

    def job(name: str) -> dict:
        try:
            outcome = run_one(workspace, name, work, dry_run)
        except Exception as exc:  # one package must not stop the batch
            outcome = {"package": name, "status": "failed", "step": "internal", "error": scrub(exc)}
        (results / f"{name}.json").write_text(json.dumps(outcome, indent=2, sort_keys=True) + "\n",
                                              encoding="utf-8")
        return outcome

    with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as pool:
        return list(pool.map(job, packages))


def record(pending: dict[str, dict], plan_doc: dict, results_dir: Path) -> dict[str, dict]:
    """The new failing list: keep packages this run did not touch, replace the ones it did."""
    planned = set(plan_doc.get("packages", []))
    dropped = set(plan_doc.get("dropped", []))
    outcomes: dict[str, dict] = {}
    if results_dir.is_dir():
        for path in results_dir.glob("*.json"):
            outcome = json.loads(path.read_text(encoding="utf-8"))
            outcomes[outcome["package"]] = outcome
    new = {name: entry for name, entry in pending.items() if name not in planned and name not in dropped}
    for name in sorted(planned):
        outcome = outcomes.get(name)
        if outcome is None:
            new[name] = {"step": "unknown", "error": "no result recorded; the mirror job did not finish"}
        elif outcome["status"] == "failed":
            new[name] = {"step": outcome["step"], "error": outcome["error"]}
    return new


def render_body(pending: dict[str, dict]) -> str:
    state = json.dumps({"pending": pending}, indent=2, sort_keys=True)
    lines = [STATE_OPEN, state, STATE_CLOSE, "", f"# {ISSUE_TITLE}", ""]
    if not pending:
        lines.append("No package is pending. This issue closes itself until one fails again.")
    else:
        lines += ["| Package | Step | Last error |", "|---|---|---|"]
        for name in sorted(pending):
            entry = pending[name]
            lines.append(f"| `{name}` | {entry['step']} | {entry['error'].replace('|', '/')} |")
        lines += ["",
                  "Retry: run `xpkg-mirror.yml` on `main` with `package` set, or push a change to the package.",
                  "A package leaves this list when it publishes. Do not edit the state block by hand."]
    lines += ["", "<!-- maintained by .github/workflows/xpkg-mirror.yml; see docs/13-ci-mirror-and-update.md -->"]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="xlings-res mirror batch: plan, run, precheck, record.")
    parser.add_argument("--workspace", default=".")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("plan")
    p.add_argument("--head", required=True)
    p.add_argument("--base", default="")
    p.add_argument("--only", default="")
    p.add_argument("--current", default="")
    p.add_argument("--out", required=True)

    p = sub.add_parser("run")
    p.add_argument("--plan", required=True)
    p.add_argument("--work", required=True)
    p.add_argument("--results", required=True)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--strict", action="store_true", help="exit 1 when any package failed")

    p = sub.add_parser("precheck")
    p.add_argument("--base", required=True)
    p.add_argument("--head", required=True)
    p.add_argument("--work", required=True)
    p.add_argument("--results", required=True)

    p = sub.add_parser("record")
    p.add_argument("--plan", required=True)
    p.add_argument("--results", required=True)
    p.add_argument("--current", default="")
    p.add_argument("--body", required=True)
    p.add_argument("--status", required=True)

    args = parser.parse_args(argv)
    workspace = Path(args.workspace).resolve()

    if args.command == "plan":
        pending = current_state(args.current)[2] if args.current else {}
        doc = plan(workspace, args.head, args.base, pending, args.only)
        Path(args.out).write_text(json.dumps(doc, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps(doc, sort_keys=True))
        return 0

    if args.command == "run":
        doc = json.loads(Path(args.plan).read_text(encoding="utf-8"))
        outcomes = run_batch(workspace, doc["packages"], Path(args.work), Path(args.results),
                             dry_run=args.dry_run)
        failed = [o for o in outcomes if o["status"] == "failed"]
        for o in failed:
            print(f"failed {o['package']} at {o['step']}: {o['error']}")
        print(f"{len(outcomes) - len(failed)} ok, {len(failed)} failed")
        return 1 if (args.strict and failed) else 0

    if args.command == "precheck":
        names = [n for n in changed_stems(workspace, f"{args.base}...{args.head}")
                 if declares_mirror(workspace, n)]
        if not names:
            print("no changed package declares ci = { mirror = true }")
            return 0
        outcomes = run_batch(workspace, names, Path(args.work), Path(args.results), dry_run=True)
        failed = [o for o in outcomes if o["status"] == "failed"]
        for o in failed:
            print(f"::error::{o['package']} failed at {o['step']}: {o['error']}")
        return 1 if failed else 0

    # record
    number, state, pending = current_state(args.current)
    plan_doc = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    new = record(pending, plan_doc, Path(args.results))
    Path(args.body).write_text(render_body(new), encoding="utf-8")
    Path(args.status).write_text(json.dumps({
        "pending": len(new), "packages": sorted(new), "number": number, "state": state,
        "title": ISSUE_TITLE, "label": ISSUE_LABEL,
    }, sort_keys=True) + "\n", encoding="utf-8")
    print(f"pending: {len(new)} {sorted(new)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
