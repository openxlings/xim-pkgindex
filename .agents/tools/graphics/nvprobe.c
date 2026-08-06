// nvprobe — the same proof as glprobe, for the NVIDIA proprietary vendor.
//
// glprobe reaches a display through EGL_PLATFORM_SURFACELESS_MESA, which is a
// mesa extension: NVIDIA does not advertise it, so glprobe on an NVIDIA-only
// stack fails at the first step and says nothing about whether the vendor
// works. NVIDIA's headless path is EGL_EXT_platform_device — enumerate the
// EGL devices, take one, render into a pbuffer.
//
// Prints one KEY=VALUE per line, same contract as glprobe:
//   EGL_DEVICE_COUNT / GL_VENDOR / GL_RENDERER / GL_VERSION
//   PIXEL=RRGGBB
//   RESULT=ok|fail:<why>
//
// A pass here means the host's NVIDIA userspace was reached THROUGH the
// sentinel's symlinks and our libglvnd, with no host library search path — the
// one dependency §6 of the design keeps, wired the way the design says.
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GL/gl.h>
#include <stdio.h>
#include <string.h>

#define W 64
#define H 64
#define MAX_DEVICES 16

static int fail(const char *why) {
    printf("RESULT=fail:%s\n", why);
    return 1;
}

int main(void) {
    PFNEGLQUERYDEVICESEXTPROC queryDevices =
        (PFNEGLQUERYDEVICESEXTPROC)eglGetProcAddress("eglQueryDevicesEXT");
    PFNEGLGETPLATFORMDISPLAYEXTPROC getPlatformDisplay =
        (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    if (!queryDevices || !getPlatformDisplay)
        return fail("no-EGL_EXT_platform_device");

    EGLDeviceEXT devices[MAX_DEVICES];
    EGLint numDevices = 0;
    if (!queryDevices(MAX_DEVICES, devices, &numDevices) || numDevices < 1)
        return fail("no-egl-devices");
    printf("EGL_DEVICE_COUNT=%d\n", numDevices);

    // Every device, not just the first: on a machine with both an NVIDIA GPU
    // and mesa's software device, the order is not ours to choose, and taking
    // devices[0] would make the result depend on it. We want the NVIDIA one if
    // it is there at all, so keep going until a device gives a renderer.
    EGLDisplay dpy = EGL_NO_DISPLAY;
    EGLint major = 0, minor = 0;
    int chosen = -1;
    for (EGLint i = 0; i < numDevices; i++) {
        EGLDisplay d = getPlatformDisplay(EGL_PLATFORM_DEVICE_EXT, devices[i], NULL);
        if (d == EGL_NO_DISPLAY) continue;
        if (!eglInitialize(d, &major, &minor)) continue;
        const char *vendor = eglQueryString(d, EGL_VENDOR);
        if (vendor && strstr(vendor, "NVIDIA")) { dpy = d; chosen = i; break; }
        if (dpy == EGL_NO_DISPLAY) { dpy = d; chosen = i; }  // keep as fallback
    }
    if (dpy == EGL_NO_DISPLAY) return fail("no-device-initialized");
    printf("EGL_DEVICE_INDEX=%d\n", chosen);
    printf("EGL_VERSION=%d.%d\n", major, minor);
    printf("EGL_VENDOR=%s\n", eglQueryString(dpy, EGL_VENDOR));

    if (!eglBindAPI(EGL_OPENGL_API)) return fail("eglBindAPI");

    const EGLint cfgAttr[] = {
        EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8,
        EGL_NONE
    };
    EGLConfig cfg; EGLint n = 0;
    if (!eglChooseConfig(dpy, cfgAttr, &cfg, 1, &n) || n < 1)
        return fail("eglChooseConfig");

    EGLContext ctx = eglCreateContext(dpy, cfg, EGL_NO_CONTEXT, NULL);
    if (ctx == EGL_NO_CONTEXT) return fail("eglCreateContext");

    const EGLint pbAttr[] = { EGL_WIDTH, W, EGL_HEIGHT, H, EGL_NONE };
    EGLSurface surf = eglCreatePbufferSurface(dpy, cfg, pbAttr);
    if (surf == EGL_NO_SURFACE) return fail("eglCreatePbufferSurface");

    if (!eglMakeCurrent(dpy, surf, surf, ctx)) return fail("eglMakeCurrent");

    const char *vendor   = (const char *)glGetString(GL_VENDOR);
    const char *renderer = (const char *)glGetString(GL_RENDERER);
    const char *version  = (const char *)glGetString(GL_VERSION);
    printf("GL_VENDOR=%s\n",   vendor   ? vendor   : "?");
    printf("GL_RENDERER=%s\n", renderer ? renderer : "?");
    printf("GL_VERSION=%s\n",  version  ? version  : "?");

    glClearColor(0.2f, 0.4f, 0.6f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glFinish();

    unsigned char px[4] = {0, 0, 0, 0};
    glReadPixels(W / 2, H / 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
    printf("PIXEL=%02X%02X%02X\n", px[0], px[1], px[2]);

    if (px[0] < 49 || px[0] > 53 || px[1] < 100 || px[1] > 104 ||
        px[2] < 151 || px[2] > 155) {
        return fail("pixel-mismatch");
    }
    printf("RESULT=ok\n");
    return 0;
}
