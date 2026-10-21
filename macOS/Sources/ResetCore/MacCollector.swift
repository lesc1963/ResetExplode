import Foundation

public actor MacCollector: SnapshotCollecting {
    private var source: any SystemDataSource
    private var previousTicks: CPUTicks?
    private var previousCPUTime: TimeInterval?
    private var inventoryTime: TimeInterval?
    private var inventoryDate = Date()
    private var cachedVolumes: [VolumeSnapshot]?
    private var cachedGPUs: [GPUDeviceSnapshot]?
    private var inventoryNotices: [String] = []

    public init() { source = NativeSystemSource() }
    init(source: any SystemDataSource) { self.source = source }
    public func resetCPU() { previousTicks = nil; previousCPUTime = nil }
    public func collect() async -> DashboardSnapshot { collect(at: ProcessInfo.processInfo.systemUptime) }

    // Monotonic time is injectable for deterministic interval/cache tests, without sleeps or hardware reads.
    func collect(at time: TimeInterval) -> DashboardSnapshot {
        var notices: [String] = []
        var cpu: Double?
        do {
            let ticks = try source.cpuTicks()
            if let previousCPUTime, time > previousCPUTime,
               time - previousCPUTime <= SamplingPolicy.maximumCPUInterval {
                cpu = CPUUsage.percent(previous: previousTicks, current: ticks)
            }
            previousTicks = ticks; previousCPUTime = time
            if cpu == nil { notices.append("CPU: aguardando intervalo válido entre amostras.") }
        } catch {
            resetCPU()
            notices.append(Self.notice("CPU", error))
        }
        let memory: MemorySnapshot?
        do {
            let value = try source.memory()
            guard value.isValid else { throw ReadFailure.invalidData }
            memory = value
        } catch { memory = nil; notices.append(Self.notice("Memória", error)) }
        let system: SystemSnapshot
        do {
            let value = try source.system()
            system = SystemSnapshot(model: Self.nonempty(value.model), chip: Self.nonempty(value.chip),
                                    os: Self.nonempty(value.os), logicalCPUs: value.logicalCPUs.flatMap { $0 > 0 ? $0 : nil },
                                    uptime: value.uptime.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil },
                                    thermalState: Self.nonempty(value.thermalState))
        }
        catch { system = .unavailable; notices.append(Self.notice("Sistema", error)) }
        let processes: [ProcessRow]?
        do {
            let inventory = try source.processes()
            var seen = Set<Int32>()
            let rows = inventory.rows.prefix(SamplingPolicy.processLimit).filter { $0.id > 0 && seen.insert($0.id).inserted }
            processes = rows.sorted { $0.residentBytes == $1.residentBytes ? $0.id < $1.id : $0.residentBytes > $1.residentBytes }
            if inventory.partial || rows.count != inventory.rows.count {
                notices.append("Processos: lista parcial (permissões, processos encerrados ou limite de 4096).")
            }
        } catch { processes = nil; notices.append(Self.notice("Processos", error)) }

        let inventoryDue = inventoryTime.map { time < $0 || time - $0 >= SamplingPolicy.inventorySeconds } ?? true
        if inventoryDue {
            // Replace failed readings with nil; never keep old capacities or capabilities as if freshly read.
            inventoryNotices = []
            do {
                let inventory = try source.volumes()
                var seen = Set<String>()
                cachedVolumes = inventory.rows.prefix(SamplingPolicy.volumeLimit)
                    .filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
                    .map { row in
                        let valid = row.capacity?.isValid == true
                        return VolumeSnapshot(id: row.id, name: row.name, capacity: valid ? row.capacity : nil,
                                              issue: valid ? nil : row.issue ?? .unavailable)
                    }
                if inventory.partial || cachedVolumes?.count != inventory.rows.count {
                    inventoryNotices.append("Volumes: inventário local parcial ou limitado a 256 entradas.")
                }
            } catch { cachedVolumes = nil; inventoryNotices.append(Self.notice("Volumes", error)) }
            do {
                cachedGPUs = try source.gpus().map { row in
                    GPUDeviceSnapshot(id: row.id, name: row.name, unifiedMemory: row.unifiedMemory,
                                      rayTracing: row.rayTracing,
                                      recommendedWorkingSet: row.recommendedWorkingSet.flatMap { $0 > 0 ? $0 : nil })
                }
            } catch { cachedGPUs = nil; inventoryNotices.append(Self.notice("Metal", error)) }
            inventoryTime = time; inventoryDate = Date()
        }
        return DashboardSnapshot(capturedAt: Date(), system: system, cpuPercent: cpu, memory: memory,
                                 volumes: cachedVolumes, gpus: cachedGPUs, inventoryCapturedAt: inventoryDate,
                                 processes: processes, notices: notices + inventoryNotices)
    }
    private static func nonempty(_ value: String?) -> String? {
        value.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }
    private static func notice(_ category: String, _ error: any Error) -> String {
        "\(category): \((error as? ReadFailure ?? .unavailable).rawValue)."
    }
}
