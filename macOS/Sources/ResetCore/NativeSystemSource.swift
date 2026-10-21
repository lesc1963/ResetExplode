import Foundation
import Metal
import CSystem

struct NativeSystemSource: SystemDataSource {
    private func check(_ result: Int32) throws {
        guard result >= 0 else { throw result == -2 ? ReadFailure.permissionDenied : .unavailable }
    }
    func cpuTicks() throws -> CPUTicks {
        var raw = RECPUTicks()
        try check(re_cpu_ticks(&raw))
        return CPUTicks(user: raw.user, system: raw.system, idle: raw.idle, nice: raw.nice)
    }
    func memory() throws -> MemorySnapshot {
        var raw = REMemory()
        try check(re_memory(&raw))
        return MemorySnapshot(physical: ProcessInfo.processInfo.physicalMemory, free: raw.free_bytes,
                              active: raw.active_bytes, wired: raw.wired_bytes, compressed: raw.compressed_bytes)
    }
    func system() throws -> SystemSnapshot {
        let info = ProcessInfo.processInfo
        let thermal: String?
        switch info.thermalState {
        case .nominal: thermal = "Nominal"
        case .fair: thermal = "Moderado"
        case .serious: thermal = "Sério"
        case .critical: thermal = "Crítico"
        @unknown default: thermal = nil
        }
        return SystemSnapshot(model: Self.readString("hw.model"), chip: Self.readString("machdep.cpu.brand_string"),
                              os: info.operatingSystemVersionString, logicalCPUs: info.processorCount > 0 ? info.processorCount : nil,
                              uptime: info.systemUptime >= 0 ? info.systemUptime : nil, thermalState: thermal)
    }
    func processes() throws -> ProcessInventory {
        var rows = [REProcess](repeating: REProcess(), count: SamplingPolicy.processLimit)
        var partial: Int32 = 0
        let count = rows.withUnsafeMutableBufferPointer { re_processes($0.baseAddress, Int32($0.count), &partial) }
        try check(count)
        return ProcessInventory(rows: rows.prefix(Int(count)).map { row in
            var name = row.name
            let string = withUnsafeBytes(of: &name) { Self.string($0) }
            return ProcessRow(id: row.pid, name: string.isEmpty ? "Sem nome" : string, residentBytes: row.resident_bytes)
        }, partial: partial != 0)
    }
    func volumes() throws -> VolumeInventory {
        var rows = [REVolume](repeating: REVolume(), count: SamplingPolicy.volumeLimit)
        var partial: Int32 = 0
        let count = rows.withUnsafeMutableBufferPointer { re_volumes($0.baseAddress, Int32($0.count), &partial) }
        try check(count)
        return VolumeInventory(rows: rows.prefix(Int(count)).map { row in
            var path = row.mount_point
            let mountPoint = withUnsafeBytes(of: &path) { Self.string($0) }
            let capacity = DiskCapacity.fromBlocks(size: row.block_size, total: row.total_blocks, available: row.available_blocks)
            let name = mountPoint == "/" ? "Sistema (/)" : URL(fileURLWithPath: mountPoint).lastPathComponent
            return VolumeSnapshot(id: mountPoint, name: name, capacity: capacity, issue: capacity == nil ? .unavailable : nil)
        }, partial: partial != 0)
    }
    func gpus() throws -> [GPUDeviceSnapshot] {
        // Device discovery only. No command queue, buffer, pipeline, shader or GPU workload.
        MTLCopyAllDevices().enumerated().map { index, device in
            GPUDeviceSnapshot(id: index, name: device.name, unifiedMemory: device.hasUnifiedMemory,
                              rayTracing: device.supportsRaytracing,
                              recommendedWorkingSet: device.recommendedMaxWorkingSetSize > 0 ? device.recommendedMaxWorkingSetSize : nil)
        }
    }
    private static func string(_ bytes: UnsafeRawBufferPointer) -> String {
        String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
    private static func readString(_ key: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        guard re_sysctl_string(key, &buffer, buffer.count) == 0 else { return nil }
        let value = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return value.isEmpty ? nil : value
    }
}
