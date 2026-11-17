#define _POSIX_C_SOURCE 200809L
#include "SMCReader.h"
#include <stdio.h>
#include <locale.h>
#include <time.h>
static double monotonic(void) {
    struct timespec t;
    return clock_gettime(CLOCK_MONOTONIC,&t)==0?(double)t.tv_sec+(double)t.tv_nsec/1e9:-1;
}
int main(void) {
    setlocale(LC_NUMERIC,"C");kl06_fan_report r;
    const double start=monotonic();kl06_read_fans(&r);const double end=monotonic();
    time_t now=time(NULL);struct tm utc;char stamp[32]={0};
    if(now!=(time_t)-1&&gmtime_r(&now,&utc))strftime(stamp,sizeof(stamp),"%Y-%m-%dT%H:%M:%SZ",&utc);
    printf("{\n  \"schema\": \"KL06_MAC_FAN_READ_V1\",\n  \"mode\": \"read-only-existing-SMC-provider\",\n  \"status\": \"%s\",\n",kl06_fan_status_name(r.status));
    printf("  \"reported_at_utc\": ");if(stamp[0])printf("\"%s\"",stamp);else printf("null");
    printf(",\n  \"sample_age_seconds\": 0,\n  \"age_basis\": \"query-completion-not-physical-sensor-age\",\n  \"physical_sensor_age_seconds\": null,\n  \"query_duration_seconds\": ");
    if(start>=0&&end>=start)printf("%.4f",end-start);else printf("null");
    printf(",\n  \"source\": \"Existing AppleSMC / VirtualSMC provider\",\n  \"quality\": \"provider-reported-not-calibrated\",\n  \"fan_count_reported\": ");
    if(r.status==KL06_OK||r.status==KL06_NO_FANS||r.status==KL06_PARTIAL)printf("%u",r.fan_count_reported);else printf("null");
    printf(",\n  \"fan_read_cap\": 2,\n  \"fans\": [");
    for(uint32_t i=0;i<r.fan_count_read&&i<KL06_FAN_LIMIT;i++) {
        printf("%s\n    {\"index\": %u, \"status\": \"%s\", \"rpm\": ",i?",":"",i,kl06_fan_status_name(r.fans[i].status));
        if(r.fans[i].status==KL06_OK)printf("%.2f",r.fans[i].rpm);else printf("null");printf("}");
    }
    printf("\n  ],\n  \"hardware_writes\": false,\n  \"privilege_requested\": false,\n  \"limitation\": \"Read availability is not calibrated physical RPM or safe fan-control support. Permission does not create missing keys. No provider is installed; no hard kernel-call cancellation is possible.\"\n}\n");
    return 0;
}
