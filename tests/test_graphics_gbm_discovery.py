"""graphics: GBM backends belong in the discovery layer.

`libs/graphics.lua` centralises the paths a GL/DRM subsystem reads at RUNTIME:
which driver modules to load (LIBGL_DRIVERS_PATH), which GL vendors exist
(__EGL_VENDOR_LIBRARY_DIRS), where the Vulkan ICD manifests are (XDG_DATA_DIRS).
GBM backends are a fourth member of exactly that set and were absent.

WHY THAT IS NOT COSMETIC. mesa is built with `--prefix=/usr`, so
`gbmbackendspath=/usr/lib/gbm` is compiled into libgbm.so itself (it is in the
shipped gbm.pc). libgbm is a pure loader — every `gbm_create_device()` dlopens
`<path>/<driver>_gbm.so` — so once the payload is relocated, that compiled-in
path names a directory that does not exist. Measured before the entry existed:

    MESA-LOADER: failed to open dri: /usr/lib/gbm/dri_gbm.so: cannot open
    shared object file (search paths /usr/lib/gbm, suffix _gbm)

and `gbm_create_device()` returns NULL for every caller: a KMS/DRM console app,
a Wayland compositor back end, headless GPU rendering, SDL2's KMSDRM video
driver, ffmpeg's VAAPI hwcontext. Nothing else reports an error.

After the entry, measured in a fresh subos with the same binary:

    search paths /home/speak/.xlings/subos/eco-gbm-20260830/usr/lib/gbm
    gbm_create_device = 0x27080ed0   backend = drm
    gbm_bo_create = 0x2708b8a0

THE SILENT FAILURE MODE THE HARNESS GUARDS. xlings' file-asset whitelist
(xvm/bindings.cppm `is_permitted_file_destination`) accepts only destinations
under `usr`, `etc` or `share`, and a rejected destination is NOT an error — the
placement simply does not happen. So `GBM_DIR = "lib/gbm"` would install
cleanly, point the variable at a directory nothing ever populated, and render
nothing. `DRI_DIR` carries the same constraint and says so in its own comment;
the harness asserts it for GBM rather than trusting a comment.

Design: mcpp-index .agents/docs/2026-08-30-gbm-cross-repo-closed-loop-plan.md
"""

import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "lua" / "graphics_gbm_discovery_harness.lua"
GRAPHICS = REPO / "libs" / "graphics.lua"
MESA = REPO / "pkgs" / "m" / "mesa.lua"


def test_graphics_lib_exists():
    assert GRAPHICS.is_file(), "libs/graphics.lua is the shared discovery layer"


def test_gbm_dir_is_inside_the_permitted_whitelist():
    """A destination outside usr/etc/share is dropped silently, not rejected."""
    text = GRAPHICS.read_text(encoding="utf-8")
    assert "graphics.GBM_DIR" in text, "GBM_DIR must be declared"
    for line in text.splitlines():
        if line.strip().startswith("graphics.GBM_DIR"):
            value = line.split("=", 1)[1].strip().strip('"')
            assert value.startswith(("usr/", "etc/", "share/")), (
                f"GBM_DIR={value!r} is outside xlings' file-asset whitelist; "
                "the placement would be skipped with no error"
            )
            break
    else:
        pytest.fail("could not read the GBM_DIR assignment")


def test_discovery_table_carries_gbm():
    text = GRAPHICS.read_text(encoding="utf-8")
    assert "GBM_BACKENDS_PATH" in text, (
        "GBM_BACKENDS_PATH must be in DISCOVERY, or consumer_envs() and "
        "declare_subos_env() cannot emit it"
    )


def test_mesa_declares_its_gbm_backends():
    """The table entry only pays off if something populates the directory."""
    text = MESA.read_text(encoding="utf-8")
    assert "declare_gbm" in text, (
        "mesa ships lib/gbm/dri_gbm.so; without declare_gbm the variable would "
        "name an empty directory"
    )


@pytest.mark.skipif(
    shutil.which("lua5.4") is None and shutil.which("lua") is None,
    reason="no lua interpreter on this machine",
)
def test_gbm_discovery_form():
    """Load graphics.lua in a plain-Lua sandbox and check both emitters."""
    lua = shutil.which("lua5.4") or shutil.which("lua")
    proc = subprocess.run(
        [lua, str(HARNESS)],
        env={"FAKE_ROOT": str(REPO), "PATH": "/usr/bin:/bin"},
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, (
        f"harness failed:\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    )
    assert "OK" in proc.stdout
