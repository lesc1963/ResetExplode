import Foundation
import CSystem

public actor MacCollector: SnapshotCollecting {
    private var previousTicks: CPUTicks?
    public init() {}

    public func collect() async -> DashboardSnapshot {
        var notices: [String] = []
        var rawTicks = RECPUTicks()
        var cpu: Double?
        if re_cpu_ticks(&rawTicks) == 0 {
            let ticks = CPUTicks(user: rawTicks.user, system: rawTicks.system, idle: rawTicks.idle, nice: rawTicks.nice)
            cpu = CPUUsage.percent(previous: previousTicks, current: ticks)
            previousTicks = ticks
            if cpu == nil { notices.append("CPU: aguardando intervalo entre amostras.") }
        } else {
            previousTicks = nil
            notices.append("CPU: leitura indisponível.")
        }
        let info = ProcessInfo.processInfo
        var rawMemory = REMemory()
        let memory: MemorySnapshot?
        if re_memory(&rawMemory) == 0 {
            memory = MemorySnapshot(physical: info.physicalMemory, free: rawMemory.free_bytes,
                                    active: rawMemory.active_bytes, wired: rawMemory.wired_bytes,
                                    compressed: rawMemory.compressed_bytes)
        } else { memory = nil; notices.append("Memória: leitura indisponível.") }

        let disk: DiskSnapshot?
        do {
            let values = try URL(fileURLWithPath: NSHomeDirectory()).resourceValues(
                forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity,
               total > 0, available >= 0 {
                disk = DiskSnapshot(total: UInt64(total), available: UInt64(available))
            } else { disk = nil; notices.append("Disco: capacidade indisponível.") }
        } catch { disk = nil; notices.append("Disco: leitura indisponível.") }

        var rows = [REProcess](repeating: REProcess(), count: 4096)
        var partial: Int32 = 0
        let count = rows.withUnsafeMutableBufferPointer { re_processes($0.baseAddress, Int32($0.count), &partial) }
        var processes: [ProcessRow] = []
        if count >= 0 {
            processes = rows.prefix(Int(count)).map { row in
                var name = row.name
                let string = withUnsafeBytes(of: &name) { bytes in
                    String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
                }
                return ProcessRow(id: row.pid, name: string.isEmpty ? "Sem nome" : string,
                                  residentBytes: row.resident_bytes)
            }.sorted { $0.residentBytes == $1.residentBytes ? $0.id < $1.id : $0.residentBytes > $1.residentBytes }
            if partial != 0 { notices.append("Processos: lista parcial (permissões, processos encerrados ou limite de 4096).") }
        } else { notices.append("Processos: lista indisponível.") }

        let thermal: String
        switch info.thermalState {
        case .nominal: thermal = "Nominal"
        case .fair: thermal = "Moderado"
        case .serious: thermal = "Sério"
        case .critical: thermal = "Crítico"
        @unknown default: thermal = "Indisponível"
        }
        return DashboardSnapshot(capturedAt: Date(), system: SystemSnapshot(
            model: Self.readString("hw.model"), chip: Self.readString("machdep.cpu.brand_string"),
            os: info.operatingSystemVersionString, logicalCPUs: info.processorCount,
            uptime: info.systemUptime, thermalState: thermal), cpuPercent: cpu, memory: memory,
            disk: disk, processes: processes, notices: notices)
    }

    private static func readString(_ key: String) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        guard re_sysctl_string(key, &buffer, buffer.count) == 0 else { return "Indisponível" }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
