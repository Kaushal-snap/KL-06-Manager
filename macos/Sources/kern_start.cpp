// Tiger Lake-U HDR patch — adapted from Raptor Lake-P reference patch
// Hardware gate: 0x9A498086, revision 1
// CPU gate: AVX2 but no SGX
// OS: Darwin Kernel 24.6.0 (24H241)
// Boot args gated: -wex-hdrleaf2 -wex-hdradapt

#include <Headers/kern_api.hpp>
#include <Headers/kern_api.hpp>

#include "kern_host.hpp"
#include "kern_graphics_activation.hpp"
#include "kern_hdr_fix2.hpp"

static XeHost host;

static const char *bootargOff[] {
	"-wexoff"
};

static const char *bootargDebug[] {
	"-wexdbg"
};

static const char *bootargBeta[] {
	"-wexbeta"
};

PluginConfiguration ADDPR(config) {
	xStringify(PRODUCT_NAME),
	parseModuleVersion(xStringify(MODULE_VERSION)),
	LiluAPI::AllowNormal | LiluAPI::AllowInstallerRecovery | LiluAPI::AllowSafeMode,
	bootargOff,
	arrsize(bootargOff),
	bootargDebug,
	arrsize(bootargDebug),
	bootargBeta,
	arrsize(bootargBeta),
	KernelVersion::BigSur,
	KernelVersion::Tahoe,
	[]() {
		host.init();
		WEXGraphicsActivation::publish();
		XeHDRFix::init();
	}
};

// Match Xcode's kext lifecycle. The kernel runs C++ initializers; libkmod
// forwards the start/stop callbacks through _realmain and _antimain.
extern "C" {
extern kern_return_t _start(kmod_info_t *, void *);
extern kern_return_t _stop(kmod_info_t *, void *);
extern kern_return_t WhateverXe_kern_start(kmod_info_t *, void *);
extern kern_return_t WhateverXe_kern_stop(kmod_info_t *, void *);
__attribute__((visibility("default"))) KMOD_EXPLICIT_DECL(org.b00t0x.WhateverXe, "0.2.0", _start, _stop)
__attribute__((visibility("hidden"))) kmod_start_func_t *_realmain = WhateverXe_kern_start;
__attribute__((visibility("hidden"))) kmod_stop_func_t *_antimain = WhateverXe_kern_stop;
__attribute__((visibility("hidden"))) int _kext_apple_cc = __APPLE_CC__;
}
