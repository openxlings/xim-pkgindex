// wlprobe — does EGL-on-Wayland work, on OUR vendor library?
//
// The O4 cell of verify-stack.sh used to report `na` in both directions:
//
//     && na "Wayland" "WAYLAND_DISPLAY set but no Wayland probe exists yet (O4)"
//     || na "Wayland" "WAYLAND_DISPLAY unset"
//
// so "we have a compositor and it works" and "we have no compositor" produced
// the same non-answer. This is the missing half.
//
// WHAT IT PROVES, AND WHAT IT DOES NOT
//
// Proves: a real compositor is reachable; mesa's Wayland EGL platform
// initialises against it (eglGetPlatformDisplay with EGL_PLATFORM_WAYLAND_KHR,
// which is a different code path from the surfaceless platform glprobe uses);
// a context on that display renders and the pixel reads back.
//
// Does NOT prove: window presentation, xdg-shell, damage tracking, or that a
// toolkit can drive it. Committing an xdg-shell binding here would duplicate
// section 5's job -- that section runs a real application (godot) precisely
// because a probe cannot stand in for one. Kept deliberately small.
//
// LOADED is the assertion that matters, for the reason glprobe.c spells out:
// "EGL initialised on Wayland" is printed just as happily by the HOST's mesa.
// Only the path each object was mapped from separates "our payload drove this"
// from "we measured the host".
//
// Prints one KEY=VALUE per line:
//   WL_DISPLAY=<name>         the compositor socket actually connected to
//   EGL_VENDOR / EGL_VERSION
//   GL_RENDERER
//   PIXEL=RRGGBB
//   LOADED=<abs path>         one per GL/EGL/vendor object mapped
//   RESULT=ok|fail:<why>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <wayland-client.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void dump_loaded(void) {
    FILE *f = fopen("/proc/self/maps", "r");
    if (!f) { printf("LOADED=<maps unreadable>\n"); return; }
    char line[4096], seen[64][512];
    int n = 0;
    while (fgets(line, sizeof line, f)) {
        char *p = strchr(line, '/');
        if (!p) continue;
        p[strcspn(p, "\n")] = 0;
        const char *base = strrchr(p, '/');
        base = base ? base + 1 : p;
        if (!(strstr(base, "_mesa.so") || strstr(base, "libgallium")
              || strstr(base, "libEGL") || strstr(base, "libGLdispatch")
              || strstr(base, "libGLESv2") || strstr(base, "libwayland-")))
            continue;
        int dup = 0;
        for (int i = 0; i < n; i++) if (!strcmp(seen[i], p)) { dup = 1; break; }
        if (dup || n >= 64) continue;
        snprintf(seen[n], sizeof seen[n], "%s", p);
        printf("LOADED=%s\n", seen[n]);
        n++;
    }
    fclose(f);
}

#define FAIL(why) do { printf("RESULT=fail:%s\n", why); return 1; } while (0)

int main(void) {
    const char *want = getenv("WAYLAND_DISPLAY");
    printf("WL_DISPLAY=%s\n", want ? want : "<unset>");

    // NULL means "read WAYLAND_DISPLAY, else wayland-0". A failure here is the
    // compositor's absence, not the stack's -- the caller maps it to exit 3.
    struct wl_display *wl = wl_display_connect(NULL);
    if (!wl) FAIL("wl_display_connect (no compositor)");

    // The whole point of this probe: the WAYLAND platform, not surfaceless.
    // eglGetPlatformDisplay is EGL 1.5; going through the EXT entry point as a
    // fallback keeps this working on an older libEGL than the one we ship.
    EGLDisplay dpy = EGL_NO_DISPLAY;
    PFNEGLGETPLATFORMDISPLAYEXTPROC getPlatformDisplay =
        (PFNEGLGETPLATFORMDISPLAYEXTPROC)
        eglGetProcAddress("eglGetPlatformDisplayEXT");
    if (getPlatformDisplay)
        dpy = getPlatformDisplay(EGL_PLATFORM_WAYLAND_KHR, wl, NULL);
    if (dpy == EGL_NO_DISPLAY)
        FAIL("eglGetPlatformDisplay(EGL_PLATFORM_WAYLAND_KHR)");

    EGLint major = 0, minor = 0;
    if (!eglInitialize(dpy, &major, &minor)) FAIL("eglInitialize");
    printf("EGL_VENDOR=%s\n", eglQueryString(dpy, EGL_VENDOR));
    printf("EGL_VERSION=%s\n", eglQueryString(dpy, EGL_VERSION));

    // Surfaceless context on a Wayland display. Rendering to an FBO rather than
    // to a wl_surface is what keeps this probe small; see the header note on
    // what that does and does not establish.
    const char *exts = eglQueryString(dpy, EGL_EXTENSIONS);
    if (!exts || !strstr(exts, "EGL_KHR_surfaceless_context"))
        FAIL("no EGL_KHR_surfaceless_context on the Wayland display");

    EGLint cfg_attrs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8,
        EGL_NONE
    };
    EGLConfig cfg; EGLint ncfg = 0;
    if (!eglChooseConfig(dpy, cfg_attrs, &cfg, 1, &ncfg) || ncfg < 1)
        FAIL("eglChooseConfig");
    if (!eglBindAPI(EGL_OPENGL_ES_API)) FAIL("eglBindAPI");

    EGLint ctx_attrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
    EGLContext ctx = eglCreateContext(dpy, cfg, EGL_NO_CONTEXT, ctx_attrs);
    if (ctx == EGL_NO_CONTEXT) FAIL("eglCreateContext");
    if (!eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx))
        FAIL("eglMakeCurrent (surfaceless)");

    printf("GL_RENDERER=%s\n", (const char *)glGetString(GL_RENDERER));

    // Render, then read it back. eglInitialize succeeding and a renderer string
    // printing are both things a half-working stack does; only the pixel proves
    // something ran. 0x336699 matches glprobe so the harness asserts one value.
    GLuint fbo = 0, tex = 0;
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 16, 16, 0, GL_RGBA,
                 GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, tex, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        FAIL("framebuffer incomplete");

    glViewport(0, 0, 16, 16);
    glClearColor(0x33 / 255.0f, 0x66 / 255.0f, 0x99 / 255.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glFinish();

    unsigned char px[4] = { 0, 0, 0, 0 };
    glReadPixels(8, 8, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
    printf("PIXEL=%02X%02X%02X\n", px[0], px[1], px[2]);

    dump_loaded();

    if (px[0] != 0x33 || px[1] != 0x66 || px[2] != 0x99)
        FAIL("pixel readback mismatch");

    eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglTerminate(dpy);
    wl_display_disconnect(wl);
    printf("RESULT=ok\n");
    return 0;
}
