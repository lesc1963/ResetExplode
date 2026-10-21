import SwiftUI
import ResetCore

@MainActor
final class DashboardModel: ObservableObject {
    @Published var snapshot: DashboardSnapshot?
    @Published var automatic = true
    private let collector: any SnapshotCollecting
    init(collector: any SnapshotCollecting = MacCollector()) { self.collector = collector }
    func beginSampling() async { await collector.resetCPU(); await refresh() }
    func refresh() async {
        let value = await collector.collect()
        guard !Task.isCancelled else { return }
        snapshot = value
    }
}

@main
struct ResetMacApp: App {
    var body: some Scene {
        WindowGroup("Reset Explode · macOS") { DashboardView() }
            .defaultSize(width: 1060, height: 850)
    }
}

struct DashboardView: View {
    @StateObject private var model = DashboardModel()
    @Environment(\.scenePhase) private var scenePhase
    private var shouldPoll: Bool {
        SamplingPolicy.shouldPoll(automatic: model.automatic, active: scenePhase == .active)
    }
    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .memory)
    }
    private func supported(_ value: Bool?) -> String {
        value.map { $0 ? "Sim" : "Não" } ?? "Indisponível"
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("RESET EXPLODE").font(.largeTitle.bold())
                        Text("macOS · Port em desenvolvimento · Somente leitura").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Atualizar a cada 5 s", isOn: $model.automatic).toggleStyle(.switch)
                }
                if let snapshot = model.snapshot {
                    Text([snapshot.system.chip, snapshot.system.model, snapshot.system.os]
                        .map { $0 ?? "Indisponível" }.joined(separator: " · "))
                        .font(.callout).textSelection(.enabled)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        card("CPU", value: snapshot.cpuPercent.map { String(format: "%.1f %%", $0) } ?? "Aguardando / indisponível",
                             detail: "Carga agregada · CPUs lógicas: \(snapshot.system.logicalCPUs.map(String.init) ?? "Indisponível")")
                        card("Sistema", value: "Térmico: \(snapshot.system.thermalState ?? "Indisponível")",
                             detail: "Uptime: \(snapshot.system.uptime.map { "\(Int($0 / 3600)) h" } ?? "Indisponível") · Estado térmico não é temperatura")
                        card("Memória unificada", value: snapshot.memory.map { bytes($0.physical) } ?? "Indisponível",
                             detail: snapshot.memory.map { "Livre: \(bytes($0.free)) · Ativa: \(bytes($0.active))\nWired: \(bytes($0.wired)) · Comprimida: \(bytes($0.compressed))" } ?? "Leitura indisponível")
                        card("Telemetria de hardware", value: "Indisponível",
                             detail: "Uso global da GPU, °C, clocks, potência e ventoinhas não são coletados.")
                    }
                    GroupBox("Metal · Identidade e capacidades") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let gpus = snapshot.gpus {
                                if gpus.isEmpty { Text("Nenhum dispositivo Metal acessível.") }
                                ForEach(gpus) { gpu in
                                    Text(gpu.name).font(.headline)
                                    Text("Memória unificada: \(supported(gpu.unifiedMemory)) · Ray tracing: \(supported(gpu.rayTracing))")
                                    Text("Orçamento de memória recomendado: \(gpu.recommendedWorkingSet.map(bytes) ?? "Indisponível")")
                                        .foregroundStyle(.secondary)
                                }
                            } else { Text("Inventário Metal indisponível.") }
                            Text("Capacidade de ray tracing não mede desempenho. Orçamento Metal não é VRAM dedicada nem uso global.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    }
                    GroupBox("Volumes locais visíveis") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let volumes = snapshot.volumes {
                                if volumes.isEmpty { Text("Nenhum volume local visível neste inventário.") }
                                ForEach(volumes) { volume in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(volume.name).font(.headline)
                                            Text(volume.id).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if let capacity = volume.capacity {
                                            Text("\(bytes(capacity.available)) disponíveis / \(bytes(capacity.total))")
                                        } else { Text(volume.issue?.rawValue.capitalized ?? "Indisponível") }
                                    }
                                }
                            } else { Text("Inventário de volumes indisponível.") }
                            Text("Estatísticas em cache do kernel · APFS pode compartilhar espaço; não somar os volumes.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    }
                    Text("Inventários Metal/volumes: \(snapshot.inventoryCapturedAt.formatted(date: .omitted, time: .standard)) · Ciclo de 30 s")
                        .font(.caption).foregroundStyle(.secondary)
                    if let processes = snapshot.processes {
                        HStack {
                            Text("Processos · \(processes.count) visíveis").font(.headline)
                            Spacer()
                            Text("Maior RSS primeiro · RSS não soma a memória física").font(.caption).foregroundStyle(.secondary)
                        }
                        Table(processes) {
                            TableColumn("PID") { Text(String($0.id)).monospacedDigit() }.width(70)
                            TableColumn("Nome (pode ser truncado)", value: \.name)
                            TableColumn("Memória residente") { Text(bytes($0.residentBytes)).monospacedDigit() }.width(160)
                        }.frame(height: 220)
                    } else { Text("Processos: inventário indisponível.").font(.headline) }
                    ForEach(snapshot.notices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                    Text("Amostra: \(snapshot.capturedAt.formatted(date: .omitted, time: .standard))\(shouldPoll ? "" : " · Atualização pausada")")
                        .font(.caption).foregroundStyle(.secondary)
                } else { ProgressView("Aguardando janela ativa para ler informações…") }
            }.padding(24)
        }
        .frame(minWidth: 850, minHeight: 680)
        .task(id: shouldPoll) {
            guard shouldPoll else { return }
            await model.beginSampling()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(SamplingPolicy.refreshSeconds)) } catch { break }
                guard !Task.isCancelled else { break }
                await model.refresh()
            }
        }
    }
    private func card(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding().background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }
}
