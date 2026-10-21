#ifndef RESET_SYSTEM_H
#define RESET_SYSTEM_H
#include <stdint.h>
#include <stddef.h>

typedef struct { uint32_t user, system, idle, nice; } RECPUTicks;
typedef struct { uint64_t free_bytes, active_bytes, wired_bytes, compressed_bytes; } REMemory;
typedef struct { int32_t pid; uint64_t resident_bytes; char name[64]; } REProcess;
int re_cpu_ticks(RECPUTicks *out);
int re_memory(REMemory *out);
// Returns rows written, or -1. partial includes inaccessible/exited processes and capacity limits.
int re_processes(REProcess *out, int capacity, int *partial);
int re_sysctl_string(const char *key, char *out, size_t capacity);
#endif
