"""The xlings-res mirror batch: plan, run, precheck and record (tools/xpkg_mirror_queue.py).

The GitHub and GitCode calls are replaced by fakes; the tests pin the rules that keep the
batch safe to run after every merge: nothing is dropped when runs are replaced, failures do
not duplicate the tracking issue, a failed upload is retried once, and tokens never reach the
public issue.
"""
import importlib.util
import json
import subprocess
from pathlib import Path

import pytest

pytestmark = pytest.mark.static

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("xpkg_mirror_queue", ROOT / "tools" / "xpkg_mirror_queue.py")
queue = importlib.util.module_from_spec(spec)
spec.loader.exec_module(queue)


def fake_completed(rc=0, stdout="", stderr=""):
    return subprocess.CompletedProcess(args=[], returncode=rc, stdout=stdout, stderr=stderr)


def test_scrub_redacts_tokens_and_bounds_the_line():
    text = "fatal: https://x-access-token:abc123@github.com/x failed\n  with ghp_" + "a" * 36
    out = queue.scrub(text)
    assert "abc123" not in out and "ghp_" not in out
    assert "\n" not in out and "<redacted>" in out
    assert len(queue.scrub("x" * 1000)) == queue.ERROR_LIMIT


def test_state_round_trips_through_the_issue_body():
    pending = {"zed": {"step": "mirror", "error": "upload timed out"}}
    body = queue.render_body(pending)
    assert queue.read_pending(body) == pending
    assert queue.read_pending(queue.render_body({})) == {}
    assert queue.read_pending("a human wrote this, no state block") == {}


def test_a_corrupt_state_block_stops_the_batch_instead_of_forgetting_failures():
    corrupt = queue.STATE_OPEN + "\n{not json\n" + queue.STATE_CLOSE
    unterminated = queue.STATE_OPEN + "\n{\"pending\": {}}"
    for body in (corrupt, unterminated):
        with pytest.raises(SystemExit):
            queue.read_pending(body)


def test_error_text_cannot_break_the_markdown_table():
    body = queue.render_body({"a": {"step": "verify", "error": "bad | value"}})
    assert "| `a` | verify | bad / value |" in body


def test_current_state_reads_the_only_tracking_issue(tmp_path):
    path = tmp_path / "current.json"
    path.write_text(json.dumps([{"number": 7, "state": "CLOSED",
                                 "body": queue.render_body({"fd": {"step": "mirror", "error": "e"}})}]))
    assert queue.current_state(str(path)) == (7, "CLOSED", {"fd": {"step": "mirror", "error": "e"}})
    path.write_text("[]")
    assert queue.current_state(str(path)) == (None, None, {})
    assert queue.current_state("") == (None, None, {})


def test_record_keeps_untouched_failures_and_replaces_planned_ones():
    pending = {"old": {"step": "mirror", "error": "still failing"},
               "fixed": {"step": "mirror", "error": "old error"},
               "gone": {"step": "verify", "error": "file removed"}}
    plan_doc = {"packages": ["fixed", "new-bad"], "dropped": ["gone"]}
    results = {
        "fixed": {"package": "fixed", "status": "ok", "step": "mirror"},
        "new-bad": {"package": "new-bad", "status": "failed", "step": "verify", "error": "hash mismatch"},
    }
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        for name, outcome in results.items():
            (Path(tmp) / f"{name}.json").write_text(json.dumps(outcome))
        new = queue.record(pending, plan_doc, Path(tmp))
    assert new == {"old": {"step": "mirror", "error": "still failing"},
                   "new-bad": {"step": "verify", "error": "hash mismatch"}}


def test_a_planned_package_without_a_result_is_recorded_as_failed(tmp_path):
    new = queue.record({}, {"packages": ["cmake"], "dropped": []}, tmp_path)
    assert new["cmake"]["step"] == "unknown"


def test_plan_of_one_package_requires_ci_mirror(monkeypatch):
    monkeypatch.setattr(queue, "declares_mirror", lambda ws, name: name == "pnpm")
    assert queue.plan(ROOT, "h", "", {}, only="pnpm")["packages"] == ["pnpm"]
    with pytest.raises(SystemExit):
        queue.plan(ROOT, "h", "", {}, only="cmake")


def test_plan_takes_changed_mirror_packages_and_still_failing_ones(monkeypatch):
    monkeypatch.setattr(queue, "changed_stems", lambda ws, *rev: ["fd", "plain", "removed"])
    declared = {"fd", "still-failing"}
    monkeypatch.setattr(queue, "declares_mirror", lambda ws, name: name in declared)
    pending = {"still-failing": {"step": "mirror", "error": "e"}, "removed": {"step": "mirror", "error": "e"}}
    doc = queue.plan(ROOT, "h", "b", pending)
    assert doc["packages"] == ["fd", "still-failing"]
    assert doc["dropped"] == ["removed"]


def test_baseline_is_the_last_successful_run_when_it_is_an_ancestor(tmp_path):
    def commit(message):
        subprocess.run(["git", "-C", str(tmp_path), "-c", "user.name=t", "-c", "user.email=t@example.invalid",
                        "commit", "-q", "--allow-empty", "-m", message], check=True)
        return subprocess.run(["git", "-C", str(tmp_path), "rev-parse", "HEAD"], text=True,
                              capture_output=True, check=True).stdout.strip()
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    first = commit("one")
    second = commit("two")
    assert queue.plan_range(tmp_path, first, second) == (first, second)
    # An unknown baseline falls back to one commit back, never to an unrelated range.
    assert queue.plan_range(tmp_path, "0" * 40, second) == (f"{second}^", second)


def test_a_failed_materialize_or_verify_stops_that_package_before_publishing(monkeypatch, tmp_path):
    calls = []

    def fake(workspace, *args, timeout=0):
        calls.append(args[0])
        if args[0] == "verify":
            return fake_completed(rc=1, stderr="info: fetching\nerror: sha256 mismatch for foo\n")
        return fake_completed()

    monkeypatch.setattr(queue, "xpkg_ci", fake)
    outcomes = queue.run_batch(ROOT, ["foo"], tmp_path / "work", tmp_path / "results")
    assert outcomes == [{"package": "foo", "status": "failed", "step": "verify",
                         "error": "error: sha256 mismatch for foo"}]
    assert calls == ["materialize", "verify"]
    assert json.loads((tmp_path / "results" / "foo.json").read_text())["status"] == "failed"


def test_dry_run_never_calls_mirror(monkeypatch, tmp_path):
    calls = []
    monkeypatch.setattr(queue, "xpkg_ci", lambda ws, *args, timeout=0: calls.append(args[0]) or fake_completed())
    outcomes = queue.run_batch(ROOT, ["bar"], tmp_path / "w", tmp_path / "r", dry_run=True)
    assert outcomes[0]["status"] == "ok" and "mirror" not in calls


def test_a_timed_out_step_is_recorded_not_raised(monkeypatch, tmp_path):
    def fake(workspace, *args, timeout=0):
        if args[0] == "mirror":
            raise subprocess.TimeoutExpired(cmd="mirror", timeout=timeout)
        return fake_completed()

    monkeypatch.setattr(queue, "xpkg_ci", fake)
    outcomes = queue.run_batch(ROOT, ["baz"], tmp_path / "w", tmp_path / "r")
    assert outcomes[0]["status"] == "failed" and outcomes[0]["step"] == "mirror"
    assert "timed out" in outcomes[0]["error"]


def test_an_internal_error_in_one_package_does_not_stop_the_others(monkeypatch, tmp_path):
    def fake(workspace, *args, timeout=0):
        if args[1] == "broken":
            raise OSError("disk full")
        return fake_completed()

    monkeypatch.setattr(queue, "xpkg_ci", fake)
    outcomes = {o["package"]: o for o in queue.run_batch(ROOT, ["broken", "fine"], tmp_path / "w", tmp_path / "r")}
    assert outcomes["broken"]["step"] == "internal" and outcomes["fine"]["status"] == "ok"


def test_record_cli_writes_one_body_and_a_status_for_the_workflow(tmp_path):
    plan_path = tmp_path / "plan.json"
    plan_path.write_text(json.dumps({"packages": ["x"], "dropped": []}))
    results = tmp_path / "results"
    results.mkdir()
    (results / "x.json").write_text(json.dumps({"package": "x", "status": "failed", "step": "mirror",
                                                "error": "gtc upload timed out"}))
    current = tmp_path / "current.json"
    current.write_text("[]")
    body, status = tmp_path / "body.md", tmp_path / "status.json"
    rc = queue.main(["--workspace", str(ROOT), "record", "--plan", str(plan_path), "--results", str(results),
                     "--current", str(current), "--body", str(body), "--status", str(status)])
    assert rc == 0
    info = json.loads(status.read_text())
    assert info["pending"] == 1 and info["packages"] == ["x"] and info["number"] is None
    assert info["title"] == queue.ISSUE_TITLE and info["label"] == queue.ISSUE_LABEL
    assert queue.read_pending(body.read_text()) == {"x": {"step": "mirror", "error": "gtc upload timed out"}}


def test_one_gitcode_upload_retry_not_three():
    xpkg_ci_spec = importlib.util.spec_from_file_location("xpkg_ci", ROOT / "tools" / "xpkg_ci.py")
    xpkg_ci = importlib.util.module_from_spec(xpkg_ci_spec)
    xpkg_ci_spec.loader.exec_module(xpkg_ci)
    assert xpkg_ci.GITCODE_UPLOAD_ATTEMPTS == 2
    assert xpkg_ci.GITCODE_UPLOAD_TIMEOUT == 600


def test_known_cn_hosts_are_found_in_a_cn_leg_only():
    text = ('url = {\n  GLOBAL = "https://github.com/x/y.zip",\n'
            '  CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/x.tar.gz",\n}\n'
            'other = "https://mirrors.ustc.edu.cn/not-a-cn-leg"\n')
    assert queue.known_cn_hosts(text) == ["mirrors.tuna.tsinghua.edu.cn"]
    assert queue.known_cn_hosts('CN = "https://gitcode.com/xlings-res/x/releases"') == []
    assert queue.known_cn_hosts('CN = "https://mirrors.cloud.tencent.com/apache/maven/x.zip"') == [
        "mirrors.cloud.tencent.com"]


def test_precheck_refuses_ci_mirror_next_to_a_known_cn_mirror(monkeypatch, tmp_path):
    lua = tmp_path / "pkgs" / "m" / "maven.lua"
    lua.parent.mkdir(parents=True)
    lua.write_text('ci = { mirror = true }\nCN = "https://mirrors.cloud.tencent.com/apache/maven/x.zip"\n')
    monkeypatch.setattr(queue, "changed_stems", lambda ws, rev: ["maven"])
    monkeypatch.setattr(queue, "declares_mirror", lambda ws, name: True)

    def must_not_run(*args, **kwargs):
        raise AssertionError("precheck must refuse before materializing anything")

    monkeypatch.setattr(queue, "run_batch", must_not_run)
    rc = queue.main(["--workspace", str(tmp_path), "precheck", "--base", "a", "--head", "b",
                     "--work", str(tmp_path / "w"), "--results", str(tmp_path / "r")])
    assert rc == 1
