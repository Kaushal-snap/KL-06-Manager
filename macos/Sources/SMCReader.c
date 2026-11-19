/* KL-06: fixed standard SMC fan reads, never target/mode/EC writes. */
#include "SMCReader.h"
#include <string.h>
#include <math.h>
#if defined(__APPLE__)
#include <IOKit/IOKitLib.h>
#include <mach/mach.h>
#endif
/* Legacy AppleSMC C user-client frame: explicit offsets avoid Swift struct ABI assumptions.
   key=0, keyInfo(size,type)=28/32, result/status=40/41, command=42, payload=48.
   Only read-key-info (9) and read-value (5), selector 2, are implemented. */
#define FRAME KL06_SMC_FRAME_SIZE
#define TYPE(a,b,c,d) (((uint32_t)(a)<<24)|((uint32_t)(b)<<16)|((uint32_t)(c)<<8)|(uint32_t)(d))
typedef int32_t (*transport_fn)(const uint8_t *, uint8_t *, size_t *, void *);
#if defined(__APPLE__) || defined(KL06_SMC_TEST)
static uint32_t word(const uint8_t *p) { uint32_t v; memcpy(&v,p,4); return v; }
static void put_word(uint8_t *p,uint32_t v) { memcpy(p,&v,4); }
#endif
uint32_t kl06_smc_fourcc(const char text[4]) {
    return TYPE((uint8_t)text[0],(uint8_t)text[1],(uint8_t)text[2],(uint8_t)text[3]);
}
const char *kl06_fan_status_name(int32_t s) {
    switch(s) {
    case KL06_OK:return "ok"; case KL06_PROVIDER_ABSENT:return "provider-absent";
    case KL06_PERMISSION_DENIED:return "permission-denied"; case KL06_IO_ERROR:return "query-failed";
    case KL06_INVALID_DATA:return "invalid-data"; case KL06_UNSUPPORTED_TYPE:return "unsupported-type";
    case KL06_NO_FANS:return "no-fan-keys-reported"; case KL06_PLATFORM_UNSUPPORTED:return "unsupported-platform";
    case KL06_PARTIAL:return "partial-or-sensor-unavailable"; default:return "invalid-status";
    }
}
int32_t kl06_decode_fan_rpm(uint32_t type,const uint8_t *b,size_t n,double *rpm) {
    double value;
    if(!b||!rpm) return KL06_INVALID_DATA;
    if(type==TYPE('f','p','e','2')) {
        if(n!=2) return KL06_INVALID_DATA;
        value=(double)(((uint16_t)b[0]<<8)|b[1])/4.0;
    } else if(type==TYPE('f','l','t',' ')) {
        float f;
        if(n!=4||sizeof(f)!=4) return KL06_INVALID_DATA;
        /* This beta/build target is x86_64 macOS (native little-endian float). */
        memcpy(&f,b,4); value=f;
    } else return KL06_UNSUPPORTED_TYPE;
    if(!isfinite(value)||value<0||value>30000) return KL06_INVALID_DATA;
    *rpm=value; return KL06_OK;
}
static void initialise(kl06_fan_report *r) {
    memset(r,0,sizeof(*r));r->schema_version=1;r->status=KL06_PROVIDER_ABSENT;
    for(unsigned i=0;i<KL06_FAN_LIMIT;i++)r->fans[i].status=KL06_PROVIDER_ABSENT;
}
#if defined(__APPLE__) || defined(KL06_SMC_TEST)
static int32_t read_key(transport_fn call,void *ctx,const char key[4],uint32_t *type,uint8_t bytes[32],size_t *length) {
    uint8_t in[FRAME]={0},out[FRAME]={0};size_t n=FRAME;
    put_word(in,kl06_smc_fourcc(key));in[42]=9;
    int32_t s=call(in,out,&n,ctx);
    if(s!=KL06_OK)return s;
    if(n!=FRAME||out[40]!=0||out[41]!=0)return KL06_IO_ERROR;
    uint32_t size=word(out+28);*type=word(out+32);
    if(size<1||size>32)return KL06_INVALID_DATA;
    memset(in,0,FRAME);memset(out,0,FRAME);n=FRAME;
    put_word(in,kl06_smc_fourcc(key));put_word(in+28,size);in[42]=5;
    s=call(in,out,&n,ctx);
    if(s!=KL06_OK)return s;
    if(n!=FRAME||out[40]!=0||out[41]!=0)return KL06_IO_ERROR;
    memcpy(bytes,out+48,size);*length=size;return KL06_OK;
}
static void collect(kl06_fan_report *r,transport_fn call,void *ctx) {
    initialise(r);uint8_t bytes[32]={0};uint32_t type=0;size_t length=0;
    int32_t s=read_key(call,ctx,"FNum",&type,bytes,&length);
    r->status=s;if(s!=KL06_OK)return;
    if(type!=TYPE('u','i','8',' ')||length!=1){r->status=KL06_UNSUPPORTED_TYPE;return;}
    if(bytes[0]>8){r->status=KL06_INVALID_DATA;return;}
    r->fan_count_reported=bytes[0];
    if(!bytes[0]){r->status=KL06_NO_FANS;return;}
    r->fan_count_read=bytes[0]<KL06_FAN_LIMIT?bytes[0]:KL06_FAN_LIMIT;
    r->status=KL06_OK;
    for(uint32_t i=0;i<r->fan_count_read;i++) {
        const char keys[2][5]={"F0Ac","F1Ac"};double rpm=0;memset(bytes,0,32);
        s=read_key(call,ctx,keys[i],&type,bytes,&length);
        if(s==KL06_OK)s=kl06_decode_fan_rpm(type,bytes,length,&rpm);
        r->fans[i].status=s;
        if(s==KL06_OK)r->fans[i].rpm=rpm;else r->status=KL06_PARTIAL;
    }
}
#endif
#if defined(__APPLE__)
static int32_t classify(kern_return_t k) {
    if(k==KERN_SUCCESS)return KL06_OK;
    if(k==kIOReturnNotPrivileged||k==kIOReturnNotPermitted)return KL06_PERMISSION_DENIED;
    return KL06_IO_ERROR;
}
static int32_t native_call(const uint8_t *in,uint8_t *out,size_t *size,void *ctx) {
    io_connect_t c=*(io_connect_t *)ctx;
    return classify(IOConnectCallStructMethod(c,2,in,FRAME,out,size));
}
#endif
void kl06_read_fans(kl06_fan_report *r) {
    if(!r)return;
    initialise(r);
#if defined(__APPLE__) && defined(__x86_64__)
    io_service_t service=IOServiceGetMatchingService(kIOMainPortDefault,IOServiceMatching("AppleSMC"));
    if(!service)return;
    io_connect_t connection=IO_OBJECT_NULL;
    kern_return_t kr=IOServiceOpen(service,mach_task_self(),0,&connection);IOObjectRelease(service);
    if(kr!=KERN_SUCCESS){r->status=classify(kr);return;}
    collect(r,native_call,&connection);IOServiceClose(connection);
#else
    r->status=KL06_PLATFORM_UNSUPPORTED;
#endif
}
#ifdef KL06_SMC_TEST
void kl06_test_collect(kl06_fan_report *r,kl06_test_transport call,void *ctx) {
    if(!r)return;
    if(!call){initialise(r);r->status=KL06_IO_ERROR;return;}collect(r,call,ctx);
}
#endif
