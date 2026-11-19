// Tiger Lake-U HDR fix — hardware/CPU eligibility policy
// Gate: identity==0x9A498086, revision==1, AVX2 without SGX
#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "kern_hdr_inspect.hpp"
namespace XeHDRFix {
using XeHDRInspect::Status;
// Bits 0-3 are the deferred descriptor symbols; bits 8-17 are the runtime
// helpers resolved after qualification. No other bits may be required.
constexpr uint32_t RequiredResolvedMask=(0xFU)|(0x3FFU<<8);
constexpr char Query[]="machdep.cpu.leaf7_features";
constexpr uint8_t CallerTail[]={0x48,0x89,0xc7,0xbe,0x53,0,0,0,0xe8,0x9a,0xa8,4,0,0x48,0x85,0xc0,0x74,0x24,0x0f,0xb7,8,0x81,0xf1,0x53,0x47,0,0,0x0f,0xb6,0x50,2,0x83,0xf2,0x58,0x66,9,0xca,0x74,0x12};
constexpr uint8_t CallerHead[]={0x55,0x48,0x89,0xe5,0x41,0x57,0x41,0x56,0x41,0x54,0x53,0x48,0x81,0xec,0x30,2,0,0};
inline bool userAddress(uint64_t p,size_t n){return p>=0x1000&&p<0x0000800000000000ULL&&n<=0x0000800000000000ULL-p;}
inline bool sharedCode(uint64_t p){return p>=0x00007ff000000000ULL&&p<0x0000800000000000ULL-512;}
inline bool frameBound(uint64_t rsp,uint64_t rbp,uint64_t old,uint64_t oldlenp){return !(rsp&7)&&!(rbp&7)&&userAddress(rsp,65536)&&rbp>=rsp+0x238&&rbp<=rsp+65536-16&&old==rbp-0x230&&oldlenp==rbp-0x238;}
constexpr size_t NoWord=static_cast<size_t>(-1);
inline size_t compatWord(const char *s,size_t n,size_t capacity){
 if(!s||n<5||n>capacity||s[n-1])return NoWord;
 for(size_t i=0;i+1<n;++i)if(!s[i])return NoWord;
 for(size_t i=0;i+3<n;++i)if(!memcmp(s+i,"SGX",3))return NoWord;
 size_t found=NoWord;
 for(size_t i=0;i+4<n;++i)if((!i||s[i-1]==' ')&&!memcmp(s+i,"AVX2",4)&&(s[i+4]==' '||!s[i+4])){if(found!=NoWord)return NoWord;found=i;}
 return found;
}
constexpr uint32_t CompatibilityWord=0x20584753U;
inline bool eligible(bool requested,bool normal,uint32_t major,uint32_t minor,bool kernelIdentity,uint32_t identity,uint32_t revision,uint32_t ebx){
 // Tiger Lake-U 0x9A49, revision 1. The CPU has AVX2 but no SGX feature bit,
 // so CoreDisplay otherwise clamps the panel's advertised EDR to 1.0.
 return requested&&normal&&major==24&&minor==6&&kernelIdentity&&identity==0x9A498086U&&revision==1&&(ebx&(1U<<5))&&!(ebx&(1U<<2));
}
void init();
}
