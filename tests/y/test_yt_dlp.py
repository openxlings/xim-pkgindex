from tests.lib.decorators import skip_if_not
from tests.lib.xlings import xlings_install, xlings_remove, xlings_run


@skip_if_not("linux")
def test_yt_dlp_install_and_run():
    xlings_install("yt-dlp")
    try:
        out = xlings_run("yt-dlp", "--version")
        assert "2026.11.23" in out
    finally:
        xlings_remove("yt-dlp")
