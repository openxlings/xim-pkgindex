# Hooks: what the runtime has, what it lacks, and what must hold

Hooks run in a sandboxed Lua runtime. A recipe that works on your machine can fail on another
platform, or "succeed" while installing nothing. Read this before writing `install()`,
`config()`, `uninstall()` or `installed()`.

## 1. The Lua / API boundary (§2.1)

A recipe may use only:

- the `package` metadata, `xpm` description and lifecycle hooks of the spec,
- standard Lua syntax and library (`string`, `table`, `io`, `os.getenv`, `pcall`, `error`),
- `xim.libxpkg.*` (`pkginfo`, `xvm`, `system`, `log`, `json`) and this index's
  `xim.pkgindex.*` (`libs/`).

Avoid xmake's private runtime unless an existing recipe's compatibility proves it necessary:
`core.*`, `detect.*`, `runtime.*`, `xim.base.runtime`, `common`, `platform`, `os.host()`,
`try { ... }`, and `path.*` beyond the basics existing recipes use (`path.join`, `path.directory`,
`path.filename`). `is_host()` and `raise(...)` appear in many recipes and work in `install()`
hooks; do not use them in `type = "config"` packages (section 3). Import the new API
(`xim.libxpkg.pkginfo`, `.xvm`, `.system`, `.log`), not the old one.

### APIs that are not bound in the hook runtime

Using them destroys the install silently:

| Written | Symptom | Use instead |
|---|---|---|
| `os.exists(p)` | `attempt to call a nil value (field 'exists')` | `os.isdir(p) or os.isfile(p)` |
| `os.arch()` | nil / `_RUNTIME.arch` empty (clients before 2026.10.8.1) | derive from the payload, e.g. `os.isfile` on the loader it ships |
| `os.curdir()` | nil value | `os.cd`, then return to a known dir (`pkginfo.install_dir()`) |
| `os.execv(...)` | nil value | `system.exec` / `os.exec` |
| `os.files(...)` | nil value | recurse with `os.dirs`, or hand it to `xcopy` / a shell |
| `path.absolute(p)` | nil value | `pkginfo.install_dir()` is already absolute |

**Grep before you write.** `grep -rn "os\.curdir" pkgs/ | wc -l`: if the whole index has zero
uses of a sandbox API, assume it is not in the runtime. A wrong guess costs a Windows CI round
(about 4 minutes), and the failure appears inside the install hook, layers away from the line.

Two that exist but behave unexpectedly:

- After `os.cd(dir)`, **`system.exec` does not inherit that cwd** (`os.exec` does). Check which one
  a recipe you copy from uses.
- `path.join` on Windows **mixes separators**. `"C:\Windows/System32/tar.exe"` will not run and
  `msiexec` refuses it. Pass every path meant for a Windows program through a `winpath()`
  normalizer, including the path of the executable itself.

### Windows: quoting and `tar`

- From libxpkg 0.0.67 a hook line is run as `cmd /d /s /c "<line>"`, as written; before it,
  `cmd /c <line>` stripped the outer quotes of a line that starts with one. **Do not start a
  Windows command line with a quote.** Put `call` in front: it reads the same under both
  (`pnpm.lua`, `dsh.lua`).
- Two `tar` programs exist on a runner: bsdtar (`%SystemRoot%\System32\tar.exe`, reads zip, takes
  `C:\...`) and GNU tar (Git for Windows / MSYS2: no zip, and `C:\...` is read as `host:path`).
  PATH order decides which a bare `tar` is, so the same recipe passes on one runner and fails on
  another. To unpack a zip or `.vsix`, use the absolute `System32\tar.exe`. `--force-local` is not
  an answer: GNU tar accepts it and bsdtar refuses it.

## 2. A failing install can look like a success

When `install()` raises, the install directory often holds only `.xpkg.lua` with no payload,
and the outer command may still print `✓ N package(s) installed`. A Lua runtime error in a hook
does surface (`[error] [pkg] failed: ...`), but `raise(...)` does not make the outer run fail:
it is a message for log readers, not a guard.

So:

- End `install()` by asserting the real artifact: `raise(...)` or `return os.isfile(exe)`.
  Never a bare `return true`.
- When verifying, `ls` the install directory. The exit code of the install is not evidence.

### "The install directory is empty": the usual cause is not the hook

When the same name and version is already installed under **another namespace**, xlings skips the
install hook entirely and still prints success. With `xim:foo@1.2.3` present, every
`local:foo@1.2.3` install is a silent no-op that only writes `.xpkg.lua`: it looks exactly like a
broken hook. Clear both before testing:

```bash
rm -rf ~/.xlings/data/xpkgs/{xim,local}-x-<pkg>/<version>   # in your isolated XLINGS_HOME
```

Also: two files with the same `package.name` in a local index make the **whole local repo**
vanish from the search path (`package 'local:foo' not found, searched repos: [xim, scode]`).
Delete the duplicate.

### A flat archive shares its extraction directory

xlings extracts every archive of a package with an `install()` into one shared
`<data>/runtimedir`. An archive with no top-level wrapper directory merges with whatever other
flat archives were extracted there before, so `os.mv(<runtimedir>/lib, ...)` can carry another
package's files (slang once took ollama's `lib/ollama/`). Extract a flat archive again into the
payload alone (`tar -xf <install_file> -C <install_dir>`), as `ollama.lua` and `slang.lua` do.
Tracked in openxlings/xlings#736.

## 3. Configuration packages (§2.1.2)

For `type = "config"` packages that write a user's tool configuration (Claude, an LLM client):

- Standard Lua, `package` metadata, hooks and the needed `xim.libxpkg.*` imports only.
- Errors with `error(...)`, not `raise(...)`.
- `install()` stays light and returns `true`; the write belongs in `config()`.
- Editing an existing JSON file: read it, keep the object, change only your keys, back it up
  first, report with `log.info/warn/error`, never print a token.
- No new key but a valid old one: `log.warn` that the old key is reused. Neither: `log.error`
  and fail.
- Put a separable behaviour in its own function so a test can lock it.

## 4. `install()` (§2.2)

- Input: `pkginfo.install_file()`. Output: `pkginfo.install_dir()`.
- `os.tryrm(pkginfo.install_dir())` first for a clean slate, then `os.mv(...)`.
- A Linux prebuilt ELF may need relocation (patchelf, elfpatch): declare `build` deps for it.
- Never compile (AGENTS.md).

## 5. `installed()` means "works", not "a directory exists" (§2.2.1)

`installed()` says whether the payload is in the state **this recipe produces**. Package
versions do not change when a recipe does, so on a machine that installed an older layout it is
the only thing that can pull the machine back. In the MSVC ecosystem, four of nine defects were
this, with every windows test green and the package unusable.

**(a) Check files, never directories.**

```lua
-- WRONG: the directory exists although the file that matters does not
if os.isdir(path.join(d, "Lib", VER, "um", "x64")) then return true end

-- RIGHT: the one file only this payload provides
if not os.isfile(path.join(d, "Lib", VER, "um", "x64", "kernel32.lib")) then return false end
```

Windows file systems are case-insensitive, so `os.isfile("kernel32.lib")` matches
`Kernel32.Lib`; uncertainty about case is no reason to check a directory.

**(b) Cover, do not sample.** One assertion per payload, each about a file only that payload
provides, so a missing payload is named. `windows-sdk`: 8 payloads, 7 assertions (`ucrt/corecrt.h`
from the Universal CRT, `um/winnt.h` from Store Apps Headers, `um/x64/kernel32.lib` from Store
Apps Libs, `um/x64/gdi32.lib` from Desktop Libs only, `bin/<v>/x64/rc.exe`/`mt.exe` from Store
Apps Tools, ...). Sampling would have missed the 365 libs that are disjoint from the 116.

**(c) Say what must not be there.** A removed file needs an explicit "must not exist":

```lua
-- the new recipe no longer installs vctip.exe (it kept the payload from uninstalling)
for _, d in ipairs(bin_arch_dirs()) do
    if os.isfile(path.join(d, "vctip.exe")) then return false end
end
```

**(d) Name what is missing**, not just the list again:

```lua
local missing = {}
for _, f in ipairs(required_files()) do
    if not os.isfile(f) then table.insert(missing, f) end
end
log.error("not where they should be:\n    " .. table.concat(missing, "\n    "))
```

`tests/test_installed_is_a_cover.py` enforces this rule.

## 6. `config()` and shared xvm names (§2.3)

`config()` registers the version with xvm: `xvm.add("tool")` or
`xvm.add("tool", { bindir = ..., alias = ... })`. If the executable is not at the root, set
`bindir`.

One xvm name (program or library) may be provided by **several packages**: `java` by every JDK,
`gcc` by `gcc.lua` and `musl-gcc.lua`, `crt1.o`/`libc.so` by `glibc.lua` and `musl.lua`.
Registering a shared name under a bare version fails two different ways:

| Case | Result |
|---|---|
| two packages, **same name, same version** | xvm refuses the second: `another package already owns this exact name and version` |
| two packages, **same name, different versions** | **accepted**; the name has two owners and one `xvm use` on the other side silently rewrites the symlinks in the shared `lib/` |

The second is worse, because install looks fine. Measured before musl landed:
`crt1.o = {"active": "glibc-2.39", "installed": ["glibc-2.39", "musl-1.2.5"]}`; switching `crt1.o`
to musl breaks every glibc link in that subos.

**Register shared names as `<version>-<flavor>`**, and list the colliding names in their own table:

```lua
-- computed by intersecting with glibc.lua's registry, not estimated
local SHARED_LIBS = { "crt1.o", "crti.o", "crtn.o", "Scrt1.o", "libc.a", "libc.so", "libdl.a",
                      "libm.a", "libpthread.a", "librt.a", "libutil.a" }
local MUSL_ONLY_LIBS = { "ld-musl-x86_64.so.1", "rcrt1.o", "libcrypt.a", "libresolv.a", "libxnet.a" }
local FLAVOR = "musl"
local function flavor_version() return pkginfo.version() .. "-" .. FLAVOR end
```

1. **Compute the colliding set**: intersect the other recipe's registry with your payload's real
   files, and lock the set with a test so upstream changing its file set is noticed.
2. **Flavor the colliding names, and the non-colliding ones too**, so the whole group switches
   with one `xlings use`, and a third package collides with a convention, not an empty slot.
3. **The binding root is `type = "group"`.** The root maps to no executable (no `bin/musl`); a
   default program type creates a shim that always fails (`subos/*/bin/musl -> bin/xlings`),
   reported by `self doctor` as an orphan (openxlings/xlings#452).
4. **`uninstall()` must converge inside its own version**: `xvm.remove(name, <stored key>)`. A bare
   name removes the other package's registration too.

   `xvm.add` adds the index-namespace prefix itself; **`xvm.remove` does not.** Installed from
   `local:`, `"1.2.5-musl"` is stored as `local:1.2.5-musl`, so a bare key matches nothing and the
   lib nodes stay behind. CI does not catch this (`posix-test.sh` looks only for leftover shims in
   `bin/`). Follow `glibc.lua`'s `__version_key()`:

   ```lua
   function __stored_version()
       local store = path.filename(path.directory(pkginfo.install_dir()))
       local ns = store:match("^(.-)%-x%-")   -- <data>/xpkgs/<ns>-x-<name>/<version>
       local bare = flavor_version()
       if ns and ns ~= "" and ns ~= "xim" then return ns .. ":" .. bare end
       return bare
   end
   ```

   Verify: install, read `workspace` in `subos/<name>/.xlings.json`, uninstall, and read it
   again: it must return to `null`.
5. **Headers too.** Two libcs' `stdio.h` differ, and whichever lands in the shared `usr/include`
   wins every compile of the subos silently. A non-system libc's headers go to their own
   namespace (`usr/include/musl`).

Precedents: `jdk-temurin/corretto/zulu` (`25.0.4+7-temurin`), `musl-gcc.lua` (`16.1.0-musl`),
`musl.lua` (`1.2.5-musl`).

## 7. Forbidden (isolation compliance, §2.4)

- `os.exec("xvm add ...")` / `os.exec("xvm remove ...")`
- editing `.bashrc` or any shell profile
- `os.addenv("PATH")` / `os.setenv("PATH")`
- `apt install`, `brew install`, `pacman -S`, `sudo`

Declare dependencies in `xpm.<platform>.deps`; route commands through xvm shims.
