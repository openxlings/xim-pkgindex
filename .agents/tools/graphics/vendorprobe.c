/* Does glvnd's vendor actually load, and does its entry point exist?
 *
 * S1 fails with zero vendors and mesa printing nothing, which narrows the
 * failure to glvnd's load-then-__egl_Main step. Everything upstream of it was
 * eliminated by measurement (namespaces, /usr, /dev, /sys, the dependency
 * closure, JSON readability). This asks the one remaining question directly. */
#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: vendorprobe <vendor.so>\n"); return 2; }
    void *h = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
    if (!h) { printf("DLOPEN=fail\nERR=%s\n", dlerror()); return 1; }
    printf("DLOPEN=ok\n");
    dlerror();
    void *m = dlsym(h, "__egl_Main");
    const char *e = dlerror();
    printf("EGL_MAIN=%s\n", m ? "present" : "MISSING");
    if (e) printf("DLSYM_ERR=%s\n", e);
    return 0;
}
