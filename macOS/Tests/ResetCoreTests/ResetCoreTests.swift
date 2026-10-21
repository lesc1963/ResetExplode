import Testing
@testable import ResetCore

@Test func firstAndUnchangedSampleAreUnavailable() {
    let ticks = CPUTicks(user: 10, system: 20, idle: 70, nice: 0)
    #expect(CPUUsage.percent(previous: nil, current: ticks) == nil)
    #expect(CPUUsage.percent(previous: ticks, current: ticks) == nil)
}

@Test func intervalRatherThanLifetimeUsage() throws {
    let before = CPUTicks(user: 900, system: 100, idle: 1000, nice: 0)
    let after = CPUTicks(user: 910, system: 110, idle: 1080, nice: 0)
    let value = try #require(CPUUsage.percent(previous: before, current: after))
    #expect(abs(value - 20) < 0.001)
}

@Test func counterWrapAndNiceTime() throws {
    let before = CPUTicks(user: .max - 4, system: 0, idle: .max - 9, nice: 0)
    let after = CPUTicks(user: 5, system: 0, idle: 10, nice: 10)
    let value = try #require(CPUUsage.percent(previous: before, current: after))
    #expect(abs(value - 50) < 0.001)
}

@Test func idleAndFullyBusy() {
    let start = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
    #expect(CPUUsage.percent(previous: start, current: CPUTicks(user: 0, system: 0, idle: 100, nice: 0)) == 0)
    #expect(CPUUsage.percent(previous: start, current: CPUTicks(user: 100, system: 0, idle: 0, nice: 0)) == 100)
}

// One bounded read-only sample; no GUI, subprocess, network, stress or system writes.
@Test func localCollectorSmoke() async throws {
    let snapshot = await MacCollector().collect()
    #expect(snapshot.cpuPercent == nil)
    #expect(snapshot.system.logicalCPUs > 0)
    #expect(snapshot.system.uptime > 0)
    let memory = try #require(snapshot.memory)
    #expect(memory.physical > 0)
    #expect(memory.free <= memory.physical)
    let disk = try #require(snapshot.disk)
    #expect(disk.total > 0)
    #expect(disk.available <= disk.total)
    // Restricted environments may return partial/empty process lists; they must disclose it.
    #expect(!snapshot.processes.isEmpty || snapshot.notices.contains { $0.hasPrefix("Processos:") })
    #expect(Set(snapshot.processes.map(\.id)).count == snapshot.processes.count)
    for row in snapshot.processes { #expect(row.id > 0) }
    let rss = snapshot.processes.map(\.residentBytes)
    #expect(rss == rss.sorted(by: >))
}
