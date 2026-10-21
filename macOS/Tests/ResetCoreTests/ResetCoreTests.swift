import Foundation
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
    #expect(snapshot.notices.contains("CPU: aguardando intervalo válido entre amostras."))
    #expect(try #require(snapshot.system.logicalCPUs) > 0)
    #expect(try #require(snapshot.system.uptime) > 0)
    let memory = try #require(snapshot.memory)
    #expect(memory.isValid)
    let volumes = try #require(snapshot.volumes)
    #expect(!volumes.isEmpty)
    #expect(Set(volumes.map(\.id)).count == volumes.count)
    for volume in volumes {
        if let capacity = volume.capacity { #expect(capacity.isValid) }
        else { #expect(volume.issue != nil) }
    }
    // Metal discovery may return no accessible devices; this is an explicit empty inventory.
    let gpus = try #require(snapshot.gpus)
    for gpu in gpus { #expect(!gpu.name.isEmpty) }
    if let processes = snapshot.processes {
        #expect(Set(processes.map(\.id)).count == processes.count)
        for row in processes { #expect(row.id > 0) }
        let rss = processes.map(\.residentBytes)
        #expect(rss == rss.sorted(by: >))
    } else { #expect(snapshot.notices.contains { $0.hasPrefix("Processos:") }) }
}
