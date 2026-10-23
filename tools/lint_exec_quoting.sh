#!/usr/bin/env bash
# Lint: a command a recipe hands to a shell quotes every value it interpolates
# (mcpp#832). A home under `/tmp/mc probe` reached gcc's specs rewrite as
# `gcc-specs-config /tmp/mc probe/... --dynamic-linker /tmp/mc probe/...`, and
# the shell split each path at the space. A `%s` inside the format string of
# `system.exec(string.format(...))` / `os.exec(string.format(...))` must be
# quoted where it is written (`"%s"`, `'%s'`), or the command built with
# `xim.pkgindex.shell` (`shell.exec({argv...})`, `shell.quote(s)`); a value
# that is not a path and cannot hold a space says so on the call's line, or
# the line above it, with `exec-quoting-ok: <why>`.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import re, subprocess, sys
files = subprocess.check_output(["git", "ls-files", "pkgs", "libs"], text=True).split()
call = re.compile(r'\b(?:system|os)\.exec\(\s*string\.format\(')
lit = re.compile(r'\[\[(.*?)\]\]|"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'', re.S)
bad = []
for f in files:
    if not f.endswith(".lua"): continue
    text = open(f, encoding="utf-8").read()
    for m in call.finditer(text):
        line_no = text.count("\n", 0, m.start()) + 1
        lines = text.splitlines()
        line = lines[line_no - 1]
        above = lines[line_no - 2] if line_no >= 2 else ""
        if "exec-quoting-ok" in line or "exec-quoting-ok" in above: continue
        lm = lit.match(text, m.end() + len(re.match(r'\s*', text[m.end():]).group(0)))
        if not lm: continue
        fmt = next(g for g in lm.groups() if g is not None)
        quote = '"' if lm.group(2) is not None else "'" if lm.group(3) is not None else ""
        for i in [k.start() for k in re.finditer(r'%s', fmt)]:
            before = fmt[i - 1] if i > 0 else ""
            # `\"%s` inside a "…" literal is a quoted value too.
            if before in ('"', "'") or fmt[max(0, i - 2):i] == '\\"':
                continue
            bad.append(f"{f}:{line_no}: an interpolated value is not quoted: {line.strip()}")
            break
for b in bad: print("::error::" + b)
if bad:
    print(f"{len(bad)} exec call(s) interpolate an unquoted value; quote it (\"%s\"), build the command "
          "with xim.pkgindex.shell, or mark a non-path value `exec-quoting-ok: <why>`", file=sys.stderr)
    sys.exit(1)
print("exec quoting: every interpolated value is quoted")
PY
