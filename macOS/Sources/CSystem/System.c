#include "CSystem.h"
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <libproc.h>
#include <stdlib.h>
#include <string.h>

int re_cpu_ticks(RECPUTicks *out) {
    host_cpu_load_info_data_t data;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    mach_port_t host = mach_host_self();
    kern_return_t result = host_statistics(host, HOST_CPU_LOAD_INFO, (host_info_t)&data, &count);
    mach_port_deallocate(mach_task_self(), host);
    if (result != KERN_SUCCESS) return -1;
    *out = (RECPUTicks){data.cpu_ticks[CPU_STATE_USER], data.cpu_ticks[CPU_STATE_SYSTEM],
                       data.cpu_ticks[CPU_STATE_IDLE], data.cpu_ticks[CPU_STATE_NICE]};
    return 0;
}

int re_memory(REMemory *out) {
    vm_statistics64_data_t data;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    vm_size_t page_size;
    mach_port_t host = mach_host_self();
    kern_return_t result = host_page_size(host, &page_size);
    if (result == KERN_SUCCESS)
        result = host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&data, &count);
    mach_port_deallocate(mach_task_self(), host);
    if (result != KERN_SUCCESS) return -1;
    // Speculative pages are already included in free_count; do not count twice.
    *out = (REMemory){(uint64_t)data.free_count * page_size,
                     (uint64_t)data.active_count * page_size,
                     (uint64_t)data.wire_count * page_size,
                     (uint64_t)data.compressor_page_count * page_size};
    return 0;
}

int re_sysctl_string(const char *key, char *out, size_t capacity) {
    size_t size = capacity;
    if (!capacity || sysctlbyname(key, out, &size, NULL, 0) != 0) return -1;
    out[capacity - 1] = '\0';
    return 0;
}

int re_processes(REProcess *out, int capacity, int *partial) {
    *partial = 0;
    if (!out || capacity < 1 || capacity > 4096) return -1;
    // Bounded snapshot; process list can change while reading.
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    if (!pids) return -1;
    int count = proc_listallpids(pids, capacity * (int)sizeof(pid_t));
    if (count <= 0) { free(pids); return -1; }
    if (count >= capacity) { count = capacity; *partial = 1; }
    int written = 0;
    for (int i = 0; i < count; i++) {
        if (pids[i] <= 0) continue;
        struct proc_taskallinfo info;
        int size = proc_pidinfo(pids[i], PROC_PIDTASKALLINFO, 0, &info, sizeof(info));
        if (size != sizeof(info)) { *partial = 1; continue; }
        REProcess row = {0};
        row.pid = pids[i];
        row.resident_bytes = info.ptinfo.pti_resident_size;
        strlcpy(row.name, info.pbsd.pbi_comm, sizeof(row.name));
        out[written++] = row;
    }
    free(pids);
    return written;
}
