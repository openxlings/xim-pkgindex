# Running the graphics matrix on hardware we do not have

The stack ships drivers nobody has ever run. `radeonsi` and `nouveau` are in the
mesa payload — built, packaged, published — and every verification of this
ecosystem to date happened on one machine with one GPU, an RTX 4080. Those two
cells have only ever printed `not here: no amd GPU in /sys/class/drm` and
`not here: proprietary nvidia.ko is bound to this GPU`.

That is not a gap in the payload. It is a gap in the evidence, and it can only
be closed by someone who owns the card.

## The command

`verify-stack.sh` builds its probe from `glprobe.c` in the same directory, so
run it from a clone rather than by piping a single file:

```sh
git clone https://github.com/openxlings/xim-pkgindex
bash xim-pkgindex/.agents/tools/graphics/verify-stack.sh --json --keep | tee gfx-matrix.txt
```

You need `xlings` on `PATH` (or `XLINGS_BIN=/path/to/xlings`). Nothing else: the
script creates its own subos, `gfxverify`, and installs the `graphics` package
into it.

It writes to your real `XLINGS_HOME`. `--home DIR` points it at a scratch one
instead — but a freshly created home starts on the **GLOBAL** source, so from
the mainland run `XLINGS_HOME=DIR xlings config --mirror CN` first or the
install will look like it hung. `--subos NAME` renames the subos.

`--keep` only suppresses the "remove it with…" reminder; the subos is kept
either way. It is in the command above so the JSON stays the last line —
`xlings subos remove gfxverify` cleans up when you are done.

## What comes back

Seven sections of `✓` / `✗` / `·` lines, a summary, and — with `--json` — one
line of JSON, starting `{"host":`:

```json
{"host":{"vendors":"amd ","nvidia":"","dxg":false},
 "results":[{"status":"PASS","cell":"software rendering (llvmpipe)","note":"llvmpipe (LLVM 20.1.7, 256 bits)"},
            {"status":"SKIP","cell":"WSL2 d3d12","note":"/dev/dxg absent (not WSL2)"}]}
```

`host` is what the machine is, probed from `/sys` rather than guessed from
`/etc/os-release`. Each result is one cell of the matrix:

| status | meaning |
|---|---|
| `PASS` | the cell was exercised here and holds |
| `FAIL` | the cell was exercised here and does not hold |
| `SKIP` | **not exercised on this machine**, and `note` says why |

`SKIP` is the point of the format. It is not a pass with an asterisk and not a
soft failure — it is the third outcome, and the reason it is carried all the way
into the JSON is that "we do not have that hardware" and "it works" must never
render the same way. (The full rule, and the bug that produced it, are in
`.agents/tools/README.md`.)

Exit codes: `0` everything that ran passed, `1` something real failed, `3`
nothing was proven at all. **Send the output whichever it is** — a `1` from a
GPU we have never tested is the single most useful thing this doc can produce.

## The cells that matter

| cell | why it is worth your run |
|---|---|
| `radeonsi (hardware amd)` | `radeonsi_dri.so` is in the payload and has never rendered a pixel outside a build machine. **The highest-value cell in the table.** |
| `nouveau (hardware nvidia)` | Same: shipped, never run. Needs a GPU the *open* driver owns — the cell skips itself when the proprietary `nvidia.ko` is bound, so a machine with the NVIDIA driver installed cannot answer this one. |
| `WSL2 d3d12` | `/dev/dxg` support is new and has run on one machine. See below for what to expect — the cell itself will be red. |
| `Vulkan loader + our ICD` | RADV ships for AMD; on an AMD box this and `radeonsi` come as a pair. |
| `GUI application starts` | Only fires if godot is installed (`xlings install godot`). A real application dlopens libraries a surfaceless probe never touches, so this catches gaps no probe can. |
| `Wayland` | Always skips: no probe exists yet. Listed so it stays visible. |

## Two cells are red on purpose

If you are on Intel or WSL2, expect a `✗` and do not go looking for a mistake on
your side:

- `iris (hardware intel)` — **the driver is not in the payload.** mesa is built
  `-Dgallium-drivers=llvmpipe,softpipe,radeonsi,nouveau,zink`; iris needs
  `libclc`, which is a missing package rather than a missing capability.
- `WSL2 d3d12` — same shape, and only half of it. The host-side sentinel
  (`wsl-gl-host-link`, which links Windows' `libd3d12core.so` / `libdxcore.so`
  out of `/usr/lib/wsl/lib`) does ship; the mesa driver that would consume them
  does not, because it needs `DirectX-Headers`. GL on WSL2 therefore lands on
  llvmpipe.

Both cells end in `… is NOT in the payload`, and that is the correct answer.
Run it anyway: everything else in the matrix — the subos,
the install, discovery, llvmpipe, self-containment — is untested on your
platform too, and a WSL2 run is the only way to find out whether the `/dev/dxg`
detection works outside the one machine it was written on.

## Where to send it

Open an issue on <https://github.com/openxlings/xim-pkgindex/issues> titled

```
graphics matrix: <vendor> <driver>        e.g.  graphics matrix: AMD radeonsi
```

and attach `gfx-matrix.txt`, plus the distro and GPU model. The JSON line alone
is enough if you would rather not paste the whole run — but if it does not
parse, send the plain-text summary: the `note` fields are not escaped, so a
driver error message containing a quote breaks the JSON, and the text summary
carries the same information.
