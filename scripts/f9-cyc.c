// cyc <variant>: atomic ACTIVE cycle with a persistent dumb fb. 1=ACTIVE only, 2=ACTIVE+plane off/on, 3=full modeset again
#include <xf86drm.h>
#include <xf86drmMode.h>
#include <drm_fourcc.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#define CONN 36
#define CRTC 79 /* ids change per DTB and boot: modetest -c -p */
#define PLANE 37
static int fd;
static uint32_t prop(uint32_t obj, uint32_t type, const char *name) {
	drmModeObjectProperties *p = drmModeObjectGetProperties(fd, obj, type);
	uint32_t id = 0;
	for (uint32_t i = 0; p && i < p->count_props; i++) {
		drmModePropertyRes *r = drmModeGetProperty(fd, p->props[i]);
		if (!strcmp(r->name, name)) id = r->prop_id;
		drmModeFreeProperty(r);
	}
	drmModeFreeObjectProperties(p);
	if (!id) { fprintf(stderr, "no prop %s\n", name); exit(1); }
	return id;
}
static void add(drmModeAtomicReq *r, uint32_t obj, uint32_t type, const char *n, uint64_t v) {
	drmModeAtomicAddProperty(r, obj, prop(obj, type, n), v);
}
static void commit(drmModeAtomicReq *r, const char *what) {
	int ret = drmModeAtomicCommit(fd, r, DRM_MODE_ATOMIC_ALLOW_MODESET, NULL);
	printf("%s: %d\n", what, ret); fflush(stdout);
	drmModeAtomicFree(r);
}
int main(int argc, char **argv) {
	int var = atoi(argv[1]);
	fd = open("/dev/dri/card1", O_RDWR);
	drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1);
	drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1);
	drmModeConnector *c = drmModeGetConnector(fd, CONN);
	drmModeModeInfo mode = c->modes[0];
	uint32_t blob;
	drmModeCreatePropertyBlob(fd, &mode, sizeof(mode), &blob);
	struct drm_mode_create_dumb cr = { .width = 1600, .height = 2560, .bpp = 32 };
	drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &cr);
	uint32_t h[4] = { cr.handle }, pi[4] = { cr.pitch }, of[4] = { 0 }, fb;
	drmModeAddFB2(fd, 1600, 2560, DRM_FORMAT_XRGB8888, h, pi, of, &fb, 0);
	struct drm_mode_map_dumb mp = { .handle = cr.handle };
	drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mp);
	uint32_t *px = mmap(0, cr.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mp.offset);
	for (int y = 0; y < 2560; y++) for (int x = 0; x < 1600; x++)
		px[y * cr.pitch / 4 + x] = (x / 200 % 2) ? 0xffff4000 : 0xff00c0ff | ((y / 320) << 16);
	struct drm_mode_create_dumb cr2 = { .width = 1600, .height = 2560, .bpp = 32 };
	drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &cr2);
	uint32_t h2[4] = { cr2.handle }, pi2[4] = { cr2.pitch }, fb2;
	drmModeAddFB2(fd, 1600, 2560, DRM_FORMAT_XRGB8888, h2, pi2, of, &fb2, 0);
	struct drm_mode_map_dumb mp2 = { .handle = cr2.handle };
	drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mp2);
	uint32_t *px2 = mmap(0, cr2.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mp2.offset);
	memcpy(px2, px, cr.size);
	drmModeAtomicReq *r = drmModeAtomicAlloc();
	add(r, CONN, DRM_MODE_OBJECT_CONNECTOR, "CRTC_ID", CRTC);
	add(r, CRTC, DRM_MODE_OBJECT_CRTC, "MODE_ID", blob);
	add(r, CRTC, DRM_MODE_OBJECT_CRTC, "ACTIVE", 1);
	uint32_t pl[][2] = { {0,0} };
	(void)pl;
#define PLANE_ON(r) do { \
	add(r, PLANE, DRM_MODE_OBJECT_PLANE, "FB_ID", fb); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "CRTC_ID", CRTC); \
	add(r, PLANE, DRM_MODE_OBJECT_PLANE, "SRC_X", 0); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "SRC_Y", 0); \
	add(r, PLANE, DRM_MODE_OBJECT_PLANE, "SRC_W", 1600 << 16); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "SRC_H", 2560 << 16); \
	add(r, PLANE, DRM_MODE_OBJECT_PLANE, "CRTC_X", 0); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "CRTC_Y", 0); \
	add(r, PLANE, DRM_MODE_OBJECT_PLANE, "CRTC_W", 1600); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "CRTC_H", 2560); } while (0)
	PLANE_ON(r);
	commit(r, "initial modeset");
	sleep(6);
	r = drmModeAtomicAlloc();
	add(r, CRTC, DRM_MODE_OBJECT_CRTC, "ACTIVE", 0);
	if (var == 2) { add(r, PLANE, DRM_MODE_OBJECT_PLANE, "FB_ID", 0); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "CRTC_ID", 0); }
	if (var == 3) { add(r, CONN, DRM_MODE_OBJECT_CONNECTOR, "CRTC_ID", 0); add(r, CRTC, DRM_MODE_OBJECT_CRTC, "MODE_ID", 0);
		add(r, PLANE, DRM_MODE_OBJECT_PLANE, "FB_ID", 0); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "CRTC_ID", 0); }
	commit(r, "off");
	usleep((getenv("OFFMS") ? atoi(getenv("OFFMS")) : 4000) * 1000);
	r = drmModeAtomicAlloc();
	add(r, CRTC, DRM_MODE_OBJECT_CRTC, "ACTIVE", 1);
	if (var == 2) PLANE_ON(r);
	if (var == 4) { add(r, PLANE, DRM_MODE_OBJECT_PLANE, "FB_ID", fb2); }
	if (var == 3) { add(r, CONN, DRM_MODE_OBJECT_CONNECTOR, "CRTC_ID", CRTC); add(r, CRTC, DRM_MODE_OBJECT_CRTC, "MODE_ID", blob); PLANE_ON(r); }
	commit(r, "on");
	if (var >= 7) {
		usleep(var == 7 ? 300000 : var == 8 ? 3000000 : atoi(argv[3]) * 1000);
		r = drmModeAtomicAlloc(); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "FB_ID", fb2); commit(r, "flip fb2");
	}
	if (var == 5) {
		sleep(6);
		r = drmModeAtomicAlloc(); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "FB_ID", fb2); commit(r, "flip fb2");
		sleep(6);
		r = drmModeAtomicAlloc(); add(r, PLANE, DRM_MODE_OBJECT_PLANE, "FB_ID", fb); commit(r, "flip fb");
	}
	sleep(atoi(argc > 2 ? argv[2] : "20"));
	return 0;
}
