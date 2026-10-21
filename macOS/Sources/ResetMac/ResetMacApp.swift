import SwiftUI
import ResetCore

@MainActor
final class DashboardModel: ObservableObject {
    @Published var snapshot: DashboardSnapshot?
    @Published var automatic = true
    private let collector: any SnapshotCollecting
    init(collector: any SnapshotCollecting = MacCollector()) { self.collector = collector }
    func refresh() async { snapshot = await collector.collect() }
}

@main
struct ResetMacApp: App {
    var body: some Scene {
        WindowGroup("Reset Explode · macOS") { DashboardView() }
            .defaultSize(width: 1060, height: 780)
    }
}

struct DashboardView: View {
    @StateObject private var model = DashboardModel()
    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .memory)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("RESET EXPLODE").font(.largeTitle.bold())
                    Text("macOS · Prévia nativa · Somente leitura").foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Atualizar a cada 5 s", isOn: $model.automatic).toggleStyle(.switch)
            }
            if let snapshot = model.snapshot {
                Text("\(snapshot.system.chip) · \(snapshot.system.model) · \(snapshot.system.os)")
                    .font(.callout).textSelection(.enabled)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    card("CPU", value: snapshot.cpuPercent.map { String(format: "%.1f %%", $0) } ?? "Aguardando / indisponível",
                         detail: "Carga agregada · \(snapshot.system.logicalCPUs) CPUs lógicas")
                    card("Sistema", value: "Térmico: \(snapshot.system.thermalState)",
                         detail: "Uptime: \(Int(snapshot.system.uptime / 3600)) h · Estado térmico não é temperatura")
                    card("Memória unificada", value: snapshot.memory.map { bytes($0.physical) } ?? "Indisponível",
                         detail: snapshot.memory.map { "Livre: \(bytes($0.free)) · Ativa: \(bytes($0.active))\nWired: \(bytes($0.wired)) · Comprimida: \(bytes($0.compressed))" } ?? "Leitura indisponível")
                    card("Volume do usuário", value: snapshot.disk.map { "\(bytes($0.available)) disponíveis" } ?? "Indisponível",
                         detail: snapshot.disk.map { "Capacidade: \(bytes($0.total)) · APFS pode compartilhar espaço" } ?? "Leitura indisponível")
                }
                Text("GPU, temperatura em °C, clocks, potência e ventoinhas: indisponíveis nesta prévia.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Text("Processos · \(snapshot.processes.count) visíveis").font(.headline)
                    Spacer()
                    Text("Maior RSS primeiro · RSS não soma a memória física").font(.caption).foregroundStyle(.secondary)
                }
                Table(snapshot.processes) {
                    TableColumn("PID") { Text(String($0.id)).monospacedDigit() }.width(70)
                    TableColumn("Nome (pode ser truncado)", value: \.name)
                    TableColumn("Memória residente") { Text(bytes($0.residentBytes)).monospacedDigit() }.width(160)
                }.frame(minHeight: 180)
                ForEach(snapshot.notices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                Text("Amostra: \(snapshot.capturedAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
            } else { ProgressView("Lendo informações…").frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .padding(24).frame(minWidth: 850, minHeight: 680)
        .task {
            await model.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { break }
                if model.automatic { await model.refresh() }
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
