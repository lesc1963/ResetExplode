import Foundation

public struct CPUTicks: Sendable, Equatable {
    public var user, system, idle, nice: UInt32
    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }
}

public enum CPUUsage {
    // Mach counters wrap at UInt32.max. First/unchanged sample is unavailable, never zero usage.
    public static func percent(previous: CPUTicks?, current: CPUTicks) -> Double? {
        guard let previous else { return nil }
        let busy = UInt64(current.user &- previous.user) + UInt64(current.system &- previous.system)
            + UInt64(current.nice &- previous.nice)
        let total = busy + UInt64(current.idle &- previous.idle)
        guard total > 0 else { return nil }
        return Double(busy) / Double(total) * 100
    }
}

public struct MemorySnapshot: Sendable {
    public let physical, free, active, wired, compressed: UInt64
}
public struct DiskSnapshot: Sendable {
    public let total, available: UInt64
}
public struct ProcessRow: Identifiable, Sendable {
    public let id: Int32
    public let name: String
    public let residentBytes: UInt64
}
public struct SystemSnapshot: Sendable {
    public let model, chip, os: String
    public let logicalCPUs: Int
    public let uptime: TimeInterval
    public let thermalState: String
}
public struct DashboardSnapshot: Sendable {
    public let capturedAt: Date
    public let system: SystemSnapshot
    public let cpuPercent: Double?
    public let memory: MemorySnapshot?
    public let disk: DiskSnapshot?
    public let processes: [ProcessRow]
    public let notices: [String]
}
public protocol SnapshotCollecting: Sendable {
    func collect() async -> DashboardSnapshot
}
