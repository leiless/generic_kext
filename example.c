#include <libkern/libkern.h>
#include <mach/mach_types.h>

kern_return_t example_start(kmod_info_t *ki __unused, void *d __unused)
{
	printf(KEXTNAME_S ": start\n");
	return KERN_SUCCESS;
}

kern_return_t example_stop(kmod_info_t *ki __unused, void *d __unused)
{
	printf(KEXTNAME_S ": stop\n");
	return KERN_SUCCESS;
}

extern kern_return_t _start(kmod_info_t *ki, void *d);
extern kern_return_t _stop(kmod_info_t *ki, void *d);

/* Will expand name if it's a macro */
#define KMOD_EXPLICIT_DECL2(name, ver, start, stop) \
	KMOD_EXPLICIT_DECL(name, ver, start, stop)

KMOD_EXPLICIT_DECL2(BUNDLEID, KEXTBUILD_S, _start, _stop)
__private_extern__ kmod_start_func_t *_realmain = example_start;
__private_extern__ kmod_stop_func_t *_antimain = example_stop;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;

