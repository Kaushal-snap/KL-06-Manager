// Tiger Lake-U hardware inspection — exact kernel descriptor validation
#include "kern_hdr_inspect.hpp"
#include <Headers/kern_api.hpp>
#include <Headers/kern_devinfo.hpp>
#include <Headers/kern_iokit.hpp>
#include <IOKit/pci/IOPCIDevice.h>
#include <IOKit/IOLib.h>
#include <libkern/c++/OSDictionary.h>
#include <libkern/c++/OSNumber.h>
#include <libkern/c++/OSString.h>
#include "kern_xelp_device.hpp"

namespace XeHDRInspect { namespace {
// XNU x86_64 private ABI, verified against this exact kernel image. Resolve by
// name; never directly link an unsupported KPI or synthesize its address.
using NoFaultCopy = uintptr_t (*)(uintptr_t, uintptr_t, uintptr_t);
struct ReadContext { NoFaultCopy copy; };
bool copyStatic(void *opaque, uint64_t source, void *destination, size_t size) {
    auto context=static_cast<ReadContext *>(opaque);
    if (!context || !context->copy || !destination || !kernelRange(source,size) || size>HeaderBudget)
        return false;
    return context->copy(static_cast<uintptr_t>(source),reinterpret_cast<uintptr_t>(destination),size)==size;
}
void number(OSDictionary *d,const char *key,uint64_t value) {
    auto v=OSNumber::withNumber(value,64);if(v){d->setObject(key,v);v->release();}
}
void address(OSDictionary *d,const char *key,uint64_t value) {
    char text[19]{};snprintf(text,sizeof(text),"0x%016llx",static_cast<unsigned long long>(value));
    auto v=OSString::withCString(text);if(v){d->setObject(key,v);v->release();}
}
void publish(OSDictionary *d,const Snapshot &s) {
    number(d,"schema",s.schema);number(d,"status",static_cast<uint32_t>(s.status));
    number(d,"ready",s.status==Status::Ready);number(d,"readCalls",s.readCalls);number(d,"kind",s.kind);
    number(d,"routeInstalled",0);
    address(d,"header",s.header);address(d,"version",s.version);address(d,"anchor",s.anchor);
    address(d,"descriptor",s.descriptor);address(d,"parent",s.parent);address(d,"name",s.name);
    address(d,"handler",s.handler);address(d,"format",s.format);address(d,"headerSlide",s.layout.slide);
    address(d,"textStart",s.layout.text.start);number(d,"textSize",s.layout.text.size);
    address(d,"constantsStart",s.layout.constants.start);number(d,"constantsSize",s.layout.constants.size);
    address(d,"stringsStart",s.layout.strings.start);number(d,"stringsSize",s.layout.strings.size);
    address(d,"descriptorsStart",s.layout.descriptors.start);number(d,"descriptorsSize",s.layout.descriptors.size);
    if(auto root=IORegistryEntry::getRegistryRoot())root->setProperty("WEXHDRLeafInspect",d);
}
void kernelReady(void *,KernelPatcher &patcher) {
    auto diagnostic=OSDictionary::withCapacity(32);if(!diagnostic)return;
    Snapshot snapshot{};uint32_t identity=0,revision=0;
    auto info=DeviceInfo::create();
    if(info){
        auto gpu=OSDynamicCast(IOPCIDevice,info->videoBuiltin);
        if(gpu&&WIOKit::awaitPublishing(gpu)){auto p=XELP::deviceProfile(gpu);identity=p.identity;revision=p.revision;}
        DeviceInfo::deleter(info);
    }
    const bool hardware=identity==0x9A498086U&&revision==1;
    number(diagnostic,"hardwareQualified",hardware);number(diagnostic,"identity",identity);number(diagnostic,"revision",revision);
    uint32_t resolved=0;
    if(hardware){
        auto copy=reinterpret_cast<NoFaultCopy>(patcher.solveSymbol(KernelPatcher::KernelID,"_ml_nofault_copy"));patcher.clearError();
        Symbols symbols{};
        symbols.header=patcher.solveSymbol(KernelPatcher::KernelID,"__mh_execute_header");patcher.clearError();
        symbols.version=patcher.solveSymbol(KernelPatcher::KernelID,"_version");patcher.clearError();
        symbols.anchor=patcher.solveSymbol(KernelPatcher::KernelID,"_sysctl__machdep_children");patcher.clearError();
        resolved=(copy?1U:0U)|(symbols.header?2U:0U)|(symbols.version?4U:0U)|(symbols.anchor?8U:0U);
        snapshot.header=symbols.header;snapshot.version=symbols.version;snapshot.anchor=symbols.anchor;
        if(resolved==15){
            auto scratch=static_cast<uint8_t *>(IOMalloc(HeaderBudget));
            if(scratch){ReadContext context{copy};inspect(copyStatic,&context,symbols,scratch,HeaderBudget,snapshot);IOFree(scratch,HeaderBudget);}
            else number(diagnostic,"allocationFailed",1);
        }
    }
    number(diagnostic,"resolvedMask",resolved);publish(diagnostic,snapshot);diagnostic->release();
}
void init(){
    if(!checkKernelArgument("-wex-hdrdiag")||lilu.getRunMode()!=LiluAPI::RunningNormal||
       getKernelVersion()!=KernelVersion::Sequoia||getKernelMinorVersion()!=6)return;
    lilu.onPatcherLoad(kernelReady,nullptr);
}
}
