// glxprobe — the GLX half of the graphics-stack assertions, with provenance.
//
// glprobe.c covers EGL. GLX is a SEPARATE glvnd entry point: glvnd dlopens
// libGLX_<vendor>.so.0 by name, so it is the root of its own load chain and
// an EGL result says nothing about it. Measured 2026-08-06: with only
// libEGL_nvidia interposed, EGL rendered on the NVIDIA GPU while GLX still
// resolved the vendor's dependencies from /usr/lib.
//
// Prints one KEY: VALUE per line, and the resolved path of every GL/vendor
// object actually mapped. That last part is the point: `glxinfo` printing
// "NVIDIA GeForce RTX 4080" proves the HOST stack works and says nothing
// about whose libGLX_nvidia was loaded -- the host binary under the host
// loader prints exactly that whether or not our interposer exists.
//
// BUILD REQUIREMENT -- DT_RPATH, not DT_RUNPATH:
//
//   gcc -o glxprobe glxprobe.c -ldl \
//       -Wl,--dynamic-linker=<subos>/lib/ld-linux-x86-64.so.2 \
//       -Wl,-rpath,<subos>/lib -Wl,--disable-new-dtags
//
// glvnd's dlopen of the vendor is served by the CALLING object's search
// path, and libGLX.so.0's own RPATH is `$ORIGIN` -- it cannot see the vendor
// package. What makes it resolve is that DT_RPATH is searched transitively up
// the load chain to the executable, so the consumer's own RPATH serves the
// dlopen. DT_RUNPATH is NOT transitive: build the same probe with
// --enable-new-dtags (the default on many distros) and glvnd finds no vendor
// at all -- `glXQueryServerString` returns null with the X connection and the
// GLX extension both fine.
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dlfcn.h>

typedef void *(*getproc_t)(const char *);

static void dump_vendor_maps(const char *tag) {
    FILE *f = fopen("/proc/self/maps", "r");
    if (!f) { printf("%s maps: <unreadable>\n", tag); return; }
    char line[4096];
    char seen[64][512];
    int n = 0;
    while (fgets(line, sizeof line, f)) {
        char *p = strchr(line, '/');
        if (!p) continue;
        p[strcspn(p, "\n")] = 0;
        const char *base = strrchr(p, '/');
        base = base ? base + 1 : p;
        if (!(strstr(base, "_nvidia.so") || strstr(base, "libnvidia-")
              || strstr(base, "libGLX.so") || strstr(base, "libEGL.so")
              || strstr(base, "libGLdispatch") || strstr(base, "libGL.so")))
            continue;
        int dup = 0;
        for (int i = 0; i < n; i++) if (!strcmp(seen[i], p)) { dup = 1; break; }
        if (dup || n >= 64) continue;
        snprintf(seen[n++], sizeof seen[0], "%s", p);
    }
    fclose(f);
    for (int i = 0; i < n; i++)
        printf("%s LOADED %s\n", tag, seen[i]);
}

int main(void) {
    // GLX, via libGLX.so.0 -- glvnd dlopens libGLX_nvidia.so.0 by name.
    void *glx = dlopen("libGLX.so.0", RTLD_NOW);
    if (!glx) { printf("GLX dlopen failed: %s\n", dlerror()); return 2; }

    getproc_t getproc = (getproc_t)dlsym(glx, "glXGetProcAddress");
    if (!getproc) { printf("GLX no glXGetProcAddress\n"); return 2; }

    void *(*openDisplay)(const char *) = dlsym(glx, "XOpenDisplay");
    if (!openDisplay) {
        void *x11 = dlopen("libX11.so.6", RTLD_NOW | RTLD_GLOBAL);
        if (x11) openDisplay = dlsym(x11, "XOpenDisplay");
    }
    if (!openDisplay) { printf("GLX no XOpenDisplay\n"); return 2; }

    void *dpy = openDisplay(getenv("DISPLAY") ? getenv("DISPLAY") : ":0");
    if (!dpy) { printf("GLX cannot open DISPLAY\n"); return 2; }

    const char *(*queryStr)(void *, int, int) = dlsym(glx, "glXQueryServerString");
    int (*makeCurrent)(void *, unsigned long, void *) = dlsym(glx, "glXMakeCurrent");
    void *(*chooseVisual)(void *, int, int *) = dlsym(glx, "glXChooseVisual");
    void *(*createCtx)(void *, void *, void *, int) = dlsym(glx, "glXCreateContext");
    int (*defScreen)(void *) = NULL;

    // Force the vendor to load: querying the server string makes glvnd
    // resolve and dlopen libGLX_<vendor>.so.0.
    //
    // Report each step. "(null)" alone cannot distinguish "no X connection",
    // "server has no GLX extension" and "glvnd found no vendor library" --
    // three different bugs with one symptom.
    {
        void *x11 = dlopen("libX11.so.6", RTLD_NOW);
        int (*queryExt)(void *, const char *, int *, int *, int *) =
            x11 ? dlsym(x11, "XQueryExtension") : NULL;
        char *(*dpyStr)(void *) = x11 ? dlsym(x11, "XDisplayString") : NULL;
        printf("GLX libX11:  %s\n", x11 ? "loaded" : dlerror());
        if (dpyStr) printf("GLX display: %s\n", dpyStr(dpy));
        if (queryExt) {
            int op = 0, ev = 0, er = 0;
            int have = queryExt(dpy, "GLX", &op, &ev, &er);
            printf("GLX extension on server: %s (opcode %d)\n",
                   have ? "yes" : "NO", op);
        }
    }
    if (queryStr) {
        const char *v = queryStr(dpy, 0, 0x1 /* GLX_VENDOR */);
        printf("GLX server vendor: %s\n", v ? v : "(null)");
    }

    // Create a context so the vendor's GL is genuinely initialised, then read
    // GL_RENDERER through it.
    int attrs[] = { 4 /*GLX_RGBA*/, 12 /*GLX_DEPTH_SIZE*/, 16, 0 };
    void *vi = chooseVisual ? chooseVisual(dpy, 0, attrs) : NULL;
    if (vi && createCtx && makeCurrent) {
        void *ctx = createCtx(dpy, vi, NULL, 1);
        if (ctx) {
            unsigned long root = 0;
            // XRootWindow via libX11
            void *x11 = dlopen("libX11.so.6", RTLD_NOW);
            unsigned long (*rootwin)(void *, int) = x11 ? dlsym(x11, "XRootWindow") : NULL;
            if (rootwin) root = rootwin(dpy, 0);
            if (root && makeCurrent(dpy, root, ctx)) {
                const unsigned char *(*getString)(unsigned int) =
                    (const unsigned char *(*)(unsigned int))getproc("glGetString");
                if (getString) {
                    printf("GLX GL_VENDOR:   %s\n", getString(0x1F00));
                    printf("GLX GL_RENDERER: %s\n", getString(0x1F01));
                    printf("GLX GL_VERSION:  %s\n", getString(0x1F02));
                }
            } else {
                printf("GLX makeCurrent failed (root=%lu)\n", root);
            }
        }
    }
    (void)defScreen;

    dump_vendor_maps("GLX");
    return 0;
}
