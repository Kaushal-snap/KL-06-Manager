/* KL-06 standard SMC fan READS only. MIT project code; no vendor implementation. */
#ifndef KL06_SMC_READER_H
#define KL06_SMC_READER_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
#define KL06_FAN_LIMIT 2
#define KL06_SMC_FRAME_SIZE 80
/* Status codes describe queries, never approval to write hardware. */
enum { KL06_OK=0, KL06_PROVIDER_ABSENT=1, KL06_PERMISSION_DENIED=2,
       KL06_IO_ERROR=3, KL06_INVALID_DATA=4, KL06_UNSUPPORTED_TYPE=5,
       KL06_NO_FANS=6, KL06_PLATFORM_UNSUPPORTED=7, KL06_PARTIAL=8 };
typedef struct { int32_t status; double rpm; } kl06_fan_reading;
typedef struct {
    uint32_t schema_version;
    int32_t status;
    uint32_t fan_count_reported;
    uint32_t fan_count_read;
    kl06_fan_reading fans[KL06_FAN_LIMIT];
} kl06_fan_report;
void kl06_read_fans(kl06_fan_report *report);
const char *kl06_fan_status_name(int32_t status);
/* Pure bounded decoders are exposed for synthetic native/portable tests. */
int32_t kl06_decode_fan_rpm(uint32_t type, const uint8_t *bytes, size_t length, double *rpm);
uint32_t kl06_smc_fourcc(const char text[4]);
#ifdef KL06_SMC_TEST
/* Test-only transport injection is not present in production builds. */
typedef int32_t (*kl06_test_transport)(const uint8_t *, uint8_t *, size_t *, void *);
void kl06_test_collect(kl06_fan_report *, kl06_test_transport, void *);
#endif
#ifdef __cplusplus
}
#endif
#endif
