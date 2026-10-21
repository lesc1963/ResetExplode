import Foundation

public struct CPUTicks: Sendable, Equatable {
    public var user, system, idle, nice: UInt32
    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }
}
public enum CPUUsage {
    // Mach UInt32 counters wrap. Missing/unchanged samples never imply zero usage.
    public static func percent(previous: CPUTicks?, current: CPUTicks) -> Double? {
        guard let previous else { return nil }
        let busy = UInt64(current.user &- previous.user) + UInt64(current.system &- previous.system)
            + UInt64(current.nice &- previous.nice)
        let total = busy + UInt64(current.idle &- previous.idle)
        guard total > 0 else { return nil }
        return Double(busy) / Double(total) * 100
    }
}
public enum SamplingPolicy {
    public static let refreshSeconds: TimeInterval = 5
    public static let inventorySeconds: TimeInterval = 30
    public static let maximumCPUInterval: TimeInterval = 15
    public static let processLimit = 4096
    public static let volumeLimit = 256
    public static func shouldPoll(automatic: Bool, active: Bool) -> Bool { automatic && active }
}
public enum ReadFailure: String, Error, Sendable {
    case permissionDenied = "sem permissão"
    case unavailable = "indisponível"
    case invalidData = "dados inválidos"
}
public struct MemorySnapshot: Sendable {
    public let physical, free, active, wired, compressed: UInt64
    var isValid: Bool {
        physical > 0 && [free, active, wired, compressed].allSatisfy { $0 <= physical }
    }
}
public struct DiskCapacity: Sendable {
    public let total, available: UInt64
    var isValid: Bool { total > 0 && available <= total }
    static func fromBlocks(size: UInt64, total: UInt64, available: UInt64) -> DiskCapacity? {
        guard size > 0, size != .max, total != .max, available != .max else { return nil }
        let (totalBytes, totalOverflow) = size.multipliedReportingOverflow(by: total)
        let (availableBytes, availableOverflow) = size.multipliedReportingOverflow(by: available)
        guard !totalOverflow, !availableOverflow else { return nil }
        let result = DiskCapacity(total: totalBytes, available: availableBytes)
        return result.isValid ? result : nil
    }
}
public struct VolumeSnapshot: Identifiable, Sendable {
    public let id: String // Local mount point, displayed only; never exported automatically.
    public let name: String
    public let capacity: DiskCapacity?
    public let issue: ReadFailure?
}
public struct GPUDeviceSnapshot: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let unifiedMemory: Bool?
    public let rayTracing: Bool?
    public let recommendedWorkingSet: UInt64? // Budget, NOT global usage or dedicated VRAM.
}
public struct ProcessRow: Identifiable, Sendable {
    public let id: Int32
    public let name: String
    public let residentBytes: UInt64
}
struct ProcessInventory: Sendable {
    let rows: [ProcessRow]
    let partial: Bool
}
struct VolumeInventory: Sendable {
    let rows: [VolumeSnapshot]
    let partial: Bool
}
public struct SystemSnapshot: Sendable {
    public let model, chip, os: String?
    public let logicalCPUs: Int?
    public let uptime: TimeInterval?
    public let thermalState: String?
    static let unavailable = SystemSnapshot(model: nil, chip: nil, os: nil, logicalCPUs: nil,
                                            uptime: nil, thermalState: nil)
}
public struct DashboardSnapshot: Sendable {
    public let capturedAt: Date
    public let system: SystemSnapshot
    public let cpuPercent: Double?
    public let memory: MemorySnapshot?
    public let volumes: [VolumeSnapshot]?
    public let gpus: [GPUDeviceSnapshot]?
    public let inventoryCapturedAt: Date
    public let processes: [ProcessRow]?
    public let notices: [String]
}
public protocol SnapshotCollecting: Sendable {
    func collect() async -> DashboardSnapshot
    func resetCPU() async
}
// Synchronous source methods stay within the collector actor: no overlapping samples or unsafe shared buffers.
protocol SystemDataSource: Sendable {
    mutating func cpuTicks() throws -> CPUTicks
    mutating func memory() throws -> MemorySnapshot
    mutating func system() throws -> SystemSnapshot
    mutating func processes() throws -> ProcessInventory
    mutating func volumes() throws -> VolumeInventory
    mutating func gpus() throws -> [GPUDeviceSnapshot]
}
