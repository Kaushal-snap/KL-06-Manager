// KL06FanSMC - READ-ONLY VirtualSMC plugin for ASUS Vivobook K513EA (UNTESTED SKETCH).
// Publishes FNum and F0Ac from ACPI EC0.TACH. Never writes to the EC. Build against
// VirtualSMC SDK + Lilu (see README.md). Panic risk: test from a spare EFI only.
#include <Headers/kern_api.hpp>
#include <Headers/plugin_start.hpp>
#include <VirtualSMCSDK/kern_vsmcapi.hpp>
#include <IOKit/IOService.h>
#include <IOKit/acpi/IOACPIPlatformDevice.h>

#define KL06_RPM_CONST 0x0041CDB4u   // RPM = CONST / (2 * raw), from the user's DSDT dump

class EXPORT KL06FanSMC : public IOService {
  OSDeclareDefaultStructors(KL06FanSMC)
  IOACPIPlatformDevice *ec {nullptr};
  static uint32_t readRPM(IOACPIPlatformDevice *dev) {
    OSObject *res = nullptr;
    if (dev->evaluateObject("TACH", &res) != kIOReturnSuccess || !res) return 0;
    OSNumber *n = OSDynamicCast(OSNumber, res);
    uint32_t raw = n ? n->unsigned32BitValue() : 0;
    res->release();
    if (raw == 0 || raw == 0xFFFF) return 0;          // fan stopped / invalid
    uint32_t rpm = KL06_RPM_CONST / (2 * raw);
    return rpm > 12000 ? 0 : rpm;                      // sanity clamp
  }
public:
  bool start(IOService *provider) override {
    ec = OSDynamicCast(IOACPIPlatformDevice, provider);
    if (!ec || !IOService::start(provider)) return false;
    // Register SMC keys FNum (ui8 = 1) and F0Ac (fpe2 = rpm) with VirtualSMC here
    // using VirtualSMCAPI::addKey(...) and a VirtualSMCValue subclass whose update()
    // calls readRPM(ec) and stores the value as fpe2 (rpm << 2, big-endian).
    registerService();
    return true;
  }
};
OSDefineMetaClassAndStructors(KL06FanSMC, IOService)
