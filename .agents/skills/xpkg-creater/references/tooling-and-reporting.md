# Tooling problems: versions, triage and reporting

Use this when something fails and the cause may be **not your xpkg**: xlings, libxpkg, the
updater, the CI, or the index's own machinery. Fix your xpkg first
(`troubleshooting.md`); report only what is really a tool bug.

## 1. Versions

- CI installs one fixed xlings. Its version is the `version` default in
  `.github/actions/setup-xlings/action.yml` (a tag such as `v2026.11.23.1`).
- Locally: `xlings --version`. If it is **older** than the pin, behaviour you see may already be
  fixed, or may differ from CI.
- To move forward: `xlings self update` (or the version the pin names). It changes the user's
  installed client, which `XLINGS_HOME` does not isolate, so **ask the user first**. If they have
  already agreed in this conversation or in your memory, update directly and retry. If the update
  fails, or the user declines, say in your report which version you tested with.
- If xlings is missing, ask the user to install it from the README; do not pipe a remote install
  script into a shell yourself (xlings#713, #714).

## 2. Triage ladder

1. **Reproduce** in an isolated `XLINGS_HOME`, with verbose output, and keep the full log.
2. **Update** xlings if it is behind the pin (section 1), and reproduce again.
3. **Search** before you write anything. Use the error text, not your interpretation:

   ```bash
   gh issue list --repo openxlings/xlings --state all --search "<error text>"
   gh issue list --repo openxlings/xim-pkgindex --state all --search "<error text>"
   ```

   Also `openxlings/libxpkg` and `openxlings/xpkgindex-update` when the symptom is in a hook
   API or in the updater. A match: read it, add what you know as a comment (versions, platform,
   minimal repro) and link it from your pull request. Do not open a duplicate.
4. **Analyse locally**: `troubleshooting.md`, the failing log compared across platforms, and the
   source of the tool when you have it. Separate what you observed from what you suspect.
5. **Decide the owner**, then file (section 3) or fix your xpkg.

## 3. Where a report goes

| The problem is in | Repository |
|---|---|
| xlings's behaviour: install, extraction, resolver, xvm, `self`, the CLI | `openxlings/xlings` |
| the hook runtime API (`xim.libxpkg.*`) | `openxlings/libxpkg` |
| the automatic updater's plan or apply | `openxlings/xpkgindex-update` |
| this index's CI, the planner, `libs/`, templates, someone else's xpkg | `openxlings/xim-pkgindex` |

An xpkg's own mistake is not a report: fix it. A known and expected failure is not a report.

## 4. How to file

```bash
gh issue create --repo openxlings/<repo> \
  --title "[xpkg-report]: <one-line symptom>" --body-file report.md
```

- The title starts with `[xpkg-report]: `. **Do not pass `--label`**: a missing label can fail the
  command, and a reporter without triage rights loses labels anyway. A workflow labels the issue
  from the title and from the `Authorship:` line.
- One problem per issue.
- Body (`report.md`):

  ```markdown
  ## Context
  Found while contributing `<namespace>:<name>` (pull request <link>).

  ## Versions
  xlings <version> (CI pin <version>), <OS> <arch>, <other relevant versions>

  ## Reproduce
  <the smallest commands, in an isolated XLINGS_HOME>

  ## Expected / actual
  <expected> / <actual, with the relevant part of the log>

  ## Analysis
  Observed: <facts>. Suspected: <the cause you think it is, marked as a guess>.
  Ruled out: <what you checked>.

  Filed by an AI agent while contributing `<name>`.
  Authorship: ai-and-human
  Agent: <optional: the tool, e.g. Claude Code; blank if unsure>
  Model: <optional: the model id; blank if unsure>
  ```
- **Nothing private**: remove local absolute paths and user names (`/home/<you>/`, `/Users/<you>/`,
  `C:\Users\<you>\`; write `~`, `<user>`, `<tmp>`), host names, e-mail addresses, tokens and the
  contents of the user's configuration, **before** posting: an edit keeps the old text in the
  history. `pr-workflow` has a `sed` one-liner. Trim logs to what shows the problem.
- Afterwards: link the issue from your pull request, and tell the user the issue link.

## 5. Do not hide a tool bug in the xpkg

Report it, then use the smallest workaround only if the pull request must move on, and cite the
issue in a comment next to the workaround so it can be removed. The fix belongs in the repository
that owns the behaviour.
