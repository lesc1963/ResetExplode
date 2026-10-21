import Foundation
import Testing
@testable import ResetCore

private struct Script<Value: Sendable>: Sendable {
    var values: [Result<Value, ReadFailure>]
    init(_ value: Value) { values = [.success(value)] }
    init(results: [Result<Value, ReadFailure>]) { values = results }
    mutating func next() throws -> Value {
        guard let first = values.first else { throw ReadFailure.unavailable }
        if values.count > 1 { values.removeFirst() }
        return try first.get()
    }
}
private func ticks(_ n: UInt32) -> CPUTicks { CPUTicks(user: n * 10, system: 0, idle: n * 40, nice: 0) }
private func gpu(_ name: String = "Synthetic GPU") -> GPUDeviceSnapshot {
    GPUDeviceSnapshot(id: 0, name: name, unifiedMemory: true, rayTracing: false, recommendedWorkingSet: 1024)
}
private func volume(_ id: String, capacity: DiskCapacity? = DiskCapacity(total: 100, available: 20),
                    issue: ReadFailure? = nil) -> VolumeSnapshot {
    VolumeSnapshot(id: id, name: "Synthetic volume", capacity: capacity, issue: issue)
}
private struct FakeSource: SystemDataSource {
    var cpu = Script(ticks(0))
    var ram = Script(MemorySnapshot(physical: 100, free: 20, active: 30, wired: 20, compressed: 10))
    var identity = Script(SystemSnapshot(model: "Test", chip: "Test", os: "Test", logicalCPUs: 8, uptime: 100, thermalState: "Nominal"))
    var tasks = Script(ProcessInventory(rows: [], partial: false))
    var disks = Script(VolumeInventory(rows: [volume("/")], partial: false))
    var metal = Script([gpu()])
    mutating func cpuTicks() throws -> CPUTicks { try cpu.next() }
    mutating func memory() throws -> MemorySnapshot { try ram.next() }
    mutating func system() throws -> SystemSnapshot { try identity.next() }
    mutating func processes() throws -> ProcessInventory { try tasks.next() }
    mutating func volumes() throws -> VolumeInventory { try disks.next() }
    mutating func gpus() throws -> [GPUDeviceSnapshot] { try metal.next() }
}

@Test func failuresNeverBecomeZeroOrEmptyInventories() async {
    for failure in [ReadFailure.permissionDenied, .unavailable] {
        var source = FakeSource()
        source.cpu = Script(results: [.failure(failure)])
        source.ram = Script(results: [.failure(failure)])
        source.identity = Script(results: [.failure(failure)])
        source.tasks = Script(results: [.failure(failure)])
        source.disks = Script(results: [.failure(failure)])
        source.metal = Script(results: [.failure(failure)])
        let result = await MacCollector(source: source).collect(at: 0)
        #expect(result.cpuPercent == nil)
        #expect(result.memory == nil)
        #expect(result.processes == nil)
        #expect(result.volumes == nil)
        #expect(result.gpus == nil)
        #expect(result.system.logicalCPUs == nil)
        #expect(result.system.uptime == nil)
        #expect(result.system.chip == nil)
        #expect(result.notices.count == 6)
        #expect(result.notices.allSatisfy { $0.contains(failure.rawValue) })
    }
}

@Test func cpuReprimesAfterReadFailure() async throws {
    var source = FakeSource()
    source.cpu = Script(results: [.success(ticks(0)), .failure(.permissionDenied), .success(ticks(2)), .success(ticks(3))])
    let collector = MacCollector(source: source)
    #expect(await collector.collect(at: 0).cpuPercent == nil)
    #expect(await collector.collect(at: 5).cpuPercent == nil)
    #expect(await collector.collect(at: 10).cpuPercent == nil)
    #expect(try #require(await collector.collect(at: 15).cpuPercent) == 20)
}

@Test func cpuRejectsLongGapAndBackwardClock() async throws {
    var source = FakeSource()
    source.cpu = Script(results: (0...3).map { .success(ticks(UInt32($0))) })
    let collector = MacCollector(source: source)
    #expect(await collector.collect(at: 10).cpuPercent == nil)
    #expect(await collector.collect(at: 30).cpuPercent == nil)
    #expect(await collector.collect(at: 25).cpuPercent == nil)
    #expect(try #require(await collector.collect(at: 30).cpuPercent) == 20)
}

@Test func resumeExplicitlyResetsCPUBaseline() async {
    var source = FakeSource()
    source.cpu = Script(results: [.success(ticks(0)), .success(ticks(1))])
    let collector = MacCollector(source: source)
    _ = await collector.collect(at: 0)
    await collector.resetCPU()
    #expect(await collector.collect(at: 5).cpuPercent == nil)
}

@Test func inventoryCachingFailureInvalidationAndRecovery() async throws {
    var source = FakeSource()
    source.metal = Script(results: [.success([gpu("First")]), .failure(.permissionDenied), .success([gpu("Recovered")])])
    source.disks = Script(results: [.success(VolumeInventory(rows: [volume("/")], partial: false)),
                                  .failure(.unavailable), .success(VolumeInventory(rows: [volume("/other")], partial: false))])
    let collector = MacCollector(source: source)
    for time in [0.0, 5, 29] {
        let sample = await collector.collect(at: time)
        #expect(try #require(sample.gpus?.first).name == "First")
        #expect(sample.volumes?.first?.id == "/")
    }
    for time in [30.0, 35, 59] {
        let sample = await collector.collect(at: time)
        #expect(sample.gpus == nil)
        #expect(sample.volumes == nil)
        #expect(sample.notices.contains("Metal: sem permissão."))
    }
    let recovered = await collector.collect(at: 60)
    #expect(recovered.gpus?.first?.name == "Recovered")
    #expect(recovered.volumes?.first?.id == "/other")
    #expect(!recovered.notices.contains { $0.hasPrefix("Metal:") || $0.hasPrefix("Volumes:") })
}

@Test func backwardClockRefreshesInventory() async {
    var source = FakeSource()
    source.metal = Script(results: [.success([gpu("First")]), .success([gpu("Second")])])
    let collector = MacCollector(source: source)
    _ = await collector.collect(at: 100)
    #expect(await collector.collect(at: 90).gpus?.first?.name == "Second")
}

@Test func validEmptyInventoriesStayDistinctFromFailure() async throws {
    var source = FakeSource()
    source.metal = Script([])
    source.disks = Script(VolumeInventory(rows: [], partial: false))
    let result = await MacCollector(source: source).collect(at: 0)
    #expect(try #require(result.gpus).isEmpty)
    #expect(try #require(result.volumes).isEmpty)
    #expect(try #require(result.processes).isEmpty)
    #expect(!result.notices.contains { $0.hasPrefix("Metal:") || $0.hasPrefix("Volumes:") || $0.hasPrefix("Processos:") })
}

@Test func invalidMemoryIsUnavailableAndValidZeroFreeIsPreserved() async throws {
    let invalid = [MemorySnapshot(physical: 0, free: 0, active: 0, wired: 0, compressed: 0),
                   MemorySnapshot(physical: 100, free: 101, active: 0, wired: 0, compressed: 0),
                   MemorySnapshot(physical: 100, free: 0, active: 101, wired: 0, compressed: 0),
                   MemorySnapshot(physical: 100, free: 0, active: 0, wired: 101, compressed: 0),
                   MemorySnapshot(physical: 100, free: 0, active: 0, wired: 0, compressed: 101)]
    for value in invalid {
        var source = FakeSource(); source.ram = Script(value)
        let result = await MacCollector(source: source).collect(at: 0)
        #expect(result.memory == nil)
        #expect(result.notices.contains("Memória: dados inválidos."))
    }
    var source = FakeSource()
    source.ram = Script(MemorySnapshot(physical: 100, free: 0, active: 50, wired: 25, compressed: 0))
    let result = await MacCollector(source: source).collect(at: 0)
    #expect(try #require(result.memory).free == 0)
    #expect(result.memory?.compressed == 0)
}

@Test func mixedVolumePermissionsInvalidCapacityAndDuplicates() async throws {
    var source = FakeSource()
    source.disks = Script(VolumeInventory(rows: [volume("/"), volume("/full", capacity: DiskCapacity(total: 100, available: 0)),
        volume("/denied", capacity: nil, issue: .permissionDenied),
        volume("/invalid", capacity: DiskCapacity(total: 10, available: 11)), volume("/")], partial: true))
    let result = await MacCollector(source: source).collect(at: 0)
    let rows = try #require(result.volumes)
    #expect(rows.count == 4)
    #expect(rows[1].capacity?.available == 0)
    #expect(rows[2].capacity == nil)
    #expect(rows[2].issue == .permissionDenied)
    #expect(rows[3].capacity == nil)
    #expect(result.notices.contains { $0.hasPrefix("Volumes: inventário local parcial") })
}

@Test func capacityConversionRejectsOverflowUndefinedAndInconsistentValues() {
    #expect(DiskCapacity.fromBlocks(size: 4096, total: 100, available: 50)?.available == 204800)
    #expect(DiskCapacity.fromBlocks(size: 4096, total: 100, available: 0)?.available == 0)
    for value in [(UInt64(0), UInt64(1), UInt64(0)), (4096, .max, 1), (4096, 1, .max),
                  (.max - 1, 2, 1), (4096, 0, 0), (4096, 1, 2)] {
        #expect(DiskCapacity.fromBlocks(size: value.0, total: value.1, available: value.2) == nil)
    }
}

@Test func missingMetalFieldsAndZeroBudgetStayUnavailable() async throws {
    var source = FakeSource()
    source.metal = Script([GPUDeviceSnapshot(id: 0, name: "Unknown capabilities", unifiedMemory: nil,
                                            rayTracing: nil, recommendedWorkingSet: 0)])
    let result = await MacCollector(source: source).collect(at: 0)
    let row = try #require(result.gpus?.first)
    #expect(row.unifiedMemory == nil)
    #expect(row.rayTracing == nil)
    #expect(row.recommendedWorkingSet == nil)
}

@Test func partialProcessesAreDeduplicatedBoundedAndSorted() async throws {
    var source = FakeSource()
    source.tasks = Script(ProcessInventory(rows: [ProcessRow(id: 3, name: "Three", residentBytes: 10),
        ProcessRow(id: 2, name: "Two", residentBytes: 20), ProcessRow(id: 1, name: "One", residentBytes: 20),
        ProcessRow(id: 3, name: "Duplicate", residentBytes: 100), ProcessRow(id: -1, name: "Invalid", residentBytes: 0)], partial: true))
    let result = await MacCollector(source: source).collect(at: 0)
    #expect(try #require(result.processes).map(\.id) == [1, 2, 3])
    #expect(result.notices.contains { $0.hasPrefix("Processos: lista parcial") })
    source.tasks = Script(ProcessInventory(rows: (1...4100).map { ProcessRow(id: Int32($0), name: "Synthetic", residentBytes: 0) }, partial: false))
    let bounded = await MacCollector(source: source).collect(at: 0)
    #expect(bounded.processes?.count == 4096)
    #expect(bounded.notices.contains { $0.hasPrefix("Processos: lista parcial") })
}

@Test func missingOrInvalidSystemFieldsAreNeverDefaultedToZero() async {
    var source = FakeSource()
    source.identity = Script(SystemSnapshot(model: "", chip: nil, os: " ", logicalCPUs: 0,
                                           uptime: .nan, thermalState: nil))
    let result = await MacCollector(source: source).collect(at: 0)
    #expect(result.system.model == nil)
    #expect(result.system.chip == nil)
    #expect(result.system.os == nil)
    #expect(result.system.logicalCPUs == nil)
    #expect(result.system.uptime == nil)
    #expect(result.system.thermalState == nil)
}

@Test func pollingRequiresBothActiveSceneAndUserConsent() {
    #expect(SamplingPolicy.shouldPoll(automatic: true, active: true))
    #expect(!SamplingPolicy.shouldPoll(automatic: false, active: true))
    #expect(!SamplingPolicy.shouldPoll(automatic: true, active: false))
    #expect(!SamplingPolicy.shouldPoll(automatic: false, active: false))
}

@Test func volumeInventoryIsBoundedWithoutFilesystemWork() async {
    var source = FakeSource()
    source.disks = Script(VolumeInventory(rows: (1...260).map { volume("/synthetic-\($0)") }, partial: false))
    let result = await MacCollector(source: source).collect(at: 0)
    #expect(result.volumes?.count == SamplingPolicy.volumeLimit)
    #expect(result.notices.contains { $0.hasPrefix("Volumes: inventário local parcial") })
}
