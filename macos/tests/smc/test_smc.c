#include "SMCReader.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
typedef struct { uint8_t v[4]; uint16_t release; } version_frame;
typedef struct { uint16_t version,length; uint32_t limit[3]; } power_frame;
typedef struct { uint32_t size,type; uint8_t attr; } info_frame;
typedef struct { uint32_t key; version_frame version; power_frame power; info_frame info; uint8_t result,status,command; uint32_t data; uint8_t bytes[32]; } abi_frame;
_Static_assert(sizeof(abi_frame)==80,"SMC frame must be 80 bytes");
_Static_assert(offsetof(abi_frame,info)==28 && offsetof(abi_frame,result)==40,"SMC info/result offsets");
_Static_assert(offsetof(abi_frame,command)==42 && offsetof(abi_frame,bytes)==48,"SMC command/payload offsets");
static unsigned checks=0;
#define CHECK(x) do { assert(x);checks++; } while(0)
static void put(uint8_t *p,uint32_t n){memcpy(p,&n,4);}
static uint32_t get(const uint8_t *p){uint32_t n;memcpy(&n,p,4);return n;}
typedef struct { unsigned calls;int count;int fault; } fixture;
static int32_t mock(const uint8_t *in,uint8_t *out,size_t *n,void *ctx) {
    fixture *f=ctx;f->calls++;memset(out,0,*n);
    CHECK(in[42]==5||in[42]==9);
    uint32_t k=get(in);CHECK(k==kl06_smc_fourcc("FNum")||k==kl06_smc_fourcc("F0Ac")||k==kl06_smc_fourcc("F1Ac"));
    if(f->fault==1)return KL06_PERMISSION_DENIED;
    if(f->fault==2){*n=12;return KL06_OK;}
    if(f->fault==3){out[40]=1;return KL06_OK;}
    int isCount=k==kl06_smc_fourcc("FNum");
    if(in[42]==9){put(out+28,isCount?1:2);put(out+32,kl06_smc_fourcc(isCount?"ui8 ":"fpe2"));if(f->fault==4)put(out+28,33);}
    else if(isCount)out[48]=(uint8_t)f->count;
    else {out[48]=0x2e;out[49]=0xe0; /* 3000 RPM synthetic fixture */
      if(f->fault==5&&k==kl06_smc_fourcc("F1Ac"))out[41]=1;}
    return KL06_OK;
}
int main(void){
    double rpm=-1;uint8_t bytes[]={0x2e,0xe0};
    CHECK(kl06_decode_fan_rpm(kl06_smc_fourcc("fpe2"),bytes,2,&rpm)==KL06_OK&&rpm==3000);
    CHECK(kl06_decode_fan_rpm(kl06_smc_fourcc("fpe2"),bytes,1,&rpm)==KL06_INVALID_DATA);
    CHECK(kl06_decode_fan_rpm(kl06_smc_fourcc("ui16"),bytes,2,&rpm)==KL06_UNSUPPORTED_TYPE);
    uint8_t zero[2]={0};CHECK(kl06_decode_fan_rpm(kl06_smc_fourcc("fpe2"),zero,2,&rpm)==KL06_OK&&rpm==0);
    float fp=4200.5f;CHECK(kl06_decode_fan_rpm(kl06_smc_fourcc("flt "),(uint8_t *)&fp,4,&rpm)==KL06_OK&&rpm==4200.5);
    fp=NAN;CHECK(kl06_decode_fan_rpm(kl06_smc_fourcc("flt "),(uint8_t *)&fp,4,&rpm)==KL06_INVALID_DATA);
    fp=-1;CHECK(kl06_decode_fan_rpm(kl06_smc_fourcc("flt "),(uint8_t *)&fp,4,&rpm)==KL06_INVALID_DATA);
    fp=40000;CHECK(kl06_decode_fan_rpm(kl06_smc_fourcc("flt "),(uint8_t *)&fp,4,&rpm)==KL06_INVALID_DATA);
    CHECK(kl06_decode_fan_rpm(0,NULL,0,&rpm)==KL06_INVALID_DATA);
    fixture f={0,1,0};kl06_fan_report r;kl06_test_collect(&r,mock,&f);
    CHECK(r.status==KL06_OK&&r.fan_count_read==1&&r.fans[0].rpm==3000&&f.calls==4);
    f=(fixture){0,8,0};kl06_test_collect(&r,mock,&f);CHECK(r.fan_count_reported==8&&r.fan_count_read==2&&f.calls==6);
    f=(fixture){0,0,0};kl06_test_collect(&r,mock,&f);CHECK(r.status==KL06_NO_FANS&&r.fan_count_read==0&&f.calls==2);
    f=(fixture){0,9,0};kl06_test_collect(&r,mock,&f);CHECK(r.status==KL06_INVALID_DATA&&r.fan_count_read==0);
    for(int fault=1;fault<=4;fault++){f=(fixture){0,1,fault};kl06_test_collect(&r,mock,&f);CHECK(r.status!=KL06_OK&&r.fan_count_read==0&&f.calls==1);}
    f=(fixture){0,2,5};kl06_test_collect(&r,mock,&f);CHECK(r.status==KL06_PARTIAL&&r.fans[0].status==KL06_OK&&r.fans[1].status!=KL06_OK);
    kl06_test_collect(&r,NULL,NULL);CHECK(r.status==KL06_IO_ERROR);
    CHECK(strcmp(kl06_fan_status_name(999),"invalid-status")==0);
    printf("PASS: %u C decoder/transport assertions (synthetic, not native IOKit/hardware validation).\n",checks);return 0;
}
