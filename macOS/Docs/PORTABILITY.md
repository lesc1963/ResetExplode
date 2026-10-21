# Matriz de portabilidade e incrementos

Base inspecionada: README e arquivos C#/XAML de v0.16.0, commit `ce1d9b30518bbe75bb5e6cb792d1b1e365aaddd6`. MIT preservada no fork. “Adaptar” descreve viabilidade futura, não funcionalidade entregue nem autorização para executar instalações, testes pesados ou mudanças no sistema.

| Recurso original / fonte | Decisão no macOS | Estado / alternativa pública |
| --- | --- | --- |
| Dashboard e temas (`MainWindow.Dash`, `ThemeManager`) | Adaptar | Incremento 1: cartões e tabela SwiftUI, aparência do sistema; gráficos/histórico futuros |
| Sistema, SO, CPU, placa/BIOS (`SystemInfoCollector`) | Adaptar | Incremento 1: sysctl/Foundation, modelo e chip; sem serial/UUID; BIOS e WMI não se aplicam |
| CPU total ao vivo (`SensorMonitor`) | Portável com nova coleta | Incremento 1: diferença de ticks Mach; não é clock nem carga de um núcleo |
| RAM por DIMM, DDR, canais e slots | Não equivalente | Memória unificada: capacidade/estatísticas; não inventar DIMMs, canais, clocks ou tensão |
| RAM ativa/livre/comprimida | Adaptar | Incremento 1: Mach host_statistics64 e ProcessInfo.physicalMemory |
| Discos/unidades e mapa físico (`DriveMap`) | Adaptar | Incremento 2: múltiplas montagens locais navegáveis via getfsstat(MNT_NOWAIT), com estatísticas em cache; sem somar APFS ou mapear disco físico; eventos futuros |
| Avisos de conexão USB (`WM_DEVICECHANGE`) | Adaptar | Futuro NSWorkspace para volumes e IOKit público para inventário, sem escrita |
| Sensores: temperatura, clock, tensão, watts, fans | Não suportado nesta arquitetura inicial | Sem API pública geral estável identificada para telemetria global Apple Silicon equivalente; não recorrer a SMC/HID privados, root ou powermetrics |
| Estado térmico | Adaptar | Incremento 1: ProcessInfo.thermalState; nominal/fair/serious/critical, nunca °C |
| GPU-Z: arquitetura, chip, shader/RT, barramento, VBIOS (`GpuInfoCollector`, `GpuSpecDb`, `Nvml`, `Dxgi`) | Adaptar parcialmente | Incremento 2: Metal nome, memória unificada, suporte RT e orçamento recomendado; sem inferir uso, shaders/RT cores, especificações ocultas, PCIe/VRAM dedicada ou NVML |
| GPU ao vivo, PerfCap, NVENC/NVDEC, hotspot | Não suportado nesta prévia | Não há medidor global público equivalente implementado; mostrar indisponível |
| Stress CPU/RAM (`StressTester`) | Fora de escopo | Tecnicamente reescrevível, exige autorização específica; nenhum gerador de carga incluído |
| Stress GPU/FurMark (`GpuBurn`) | Fora de escopo | Direct3D incompatível; Metal exigiria novo workload e aprovação separada |
| Bench CPU path tracer (`BenchRenderer`) | Adaptar futuramente | Algoritmo reescrevível; pontuações e baseline Windows não transferíveis; não implementado/executado |
| Bench GPU cena e ray tracing (`GpuGameBench`, `GpuRtBench`) | Adaptar futuramente | Render Metal e consulta de capacidades em runtime; sem presumir RT do M1/M5 nem scores comparáveis |
| Bench simulação CPU (`GameSimBench`) | Adaptar futuramente | Novo código e metodologia; execução pesada fora da autorização atual |
| Bench RAM/carregamento/disco (`MemoryBench`, `DiskBench`) | Fora de escopo | Sem arquivos grandes, escrita de benchmark, bypass de cache ou stress |
| Overclock, energia/clock NVIDIA, guia BIOS (`OcCheck`, `MainWindow.Oc`) | Não suportado | Não criar equivalentes de overclock, fan control ou mudança de potência |
| Erros WHEA/reset de driver (`HardwareErrors`) | Não equivalente | Sem WHEA no macOS; diagnóstico futuro precisa fonte pública e limites claros |
| Otimizador: purge/trim RAM e fechar processos (`Optimizer`) | Excluído | Sem purge, kill automático, encerramento de sincronizadores ou remoção de cache |
| Ajustes Windows e RestoreAll (`WindowsTweaks`) | Excluído | Sem Registry/Game DVR/HAGS/plano energia; nenhum ajuste do Mac ou restauração destrutiva |
| Processos candidatos a fechar | Adaptar somente leitura | Incremento 1: libproc PID/nome/RSS; nenhuma ação de terminar ou priorizar |
| Inicialização (`StartupManager`) | Adaptar leitura futura | Sem editar launchd/login items ou desativar serviços; apenas APIs públicas viáveis |
| Instalar apps via winget (`AppInstaller`) | Excluído | Não instalar dependências/aplicativos de terceiros |
| Drivers GPU/chipset, Windows Update e backup (`DriverManager`) | Não suportado | Drivers macOS pertencem ao sistema; sem instalar/remover, helpers ou root |
| Portas COM fantasmas e ComDB (`UsbCleaner`) | Não equivalente | Futuro inventário serial somente leitura; sem “limpar” dispositivos ou configurações |
| Maker: drivers CH340/FTDI/Arduino, IDE, fechar portas (`MakerDrivers`) | Excluído | Sem drivers, instalação IDE, kill de monitores seriais ou limpeza de índices |
| Saúde SMART/desgaste/previsão (`DiskHealth`) | Adaptar apenas se documentado | Capacidade não prova saúde; sem atributo disponível exibir indisponível, nunca “Bom” por ausência de dados |
| Energia/bateria (`BatteryInfo`) | Adaptar | Futuro IOPowerSources para dados públicos em notebooks; Mini sem bateria não gera valores fictícios |
| Rede: ping/jitter/DNS/velocidade/bufferbloat (`NetworkTest`) | Adaptar com escopo | Futuro inventário Network/SystemConfiguration; testes ativos consomem rede, não executados |
| FPS estimado/API HowManyFPS (`GameCatalog`, `HowManyFpsClient`) | Não transferível | Dados Windows/DirectX/DLSS não validam jogos Mac; sem API, chaves ou custos |
| Detector de gargalo (`BottleneckAnalyzer`) | Não suportado sem evidência | Ausência de sensores/FPS globais impede vereditos confiáveis; não inventar recomendações |
| Overlay/atalho e FPS de jogos (`FrameMonitor`, `OverlayMetrics`) | Adaptar parcialmente | Janela futura possível; ETW Present não existe no macOS; sem captura/injeção ou FPS global presumido |
| Launcher/perfis/Steam VDF (`GameLibrary`, `GameLauncher`, `Vdf`) | Fora de escopo | Sem iniciar terceiros, editar argumentos/VDF, prioridade ou settings de jogo |
| RGB Corsair/OpenRGB/Razer (`CorsairSdk`, `LightBackends`) | Excluído | Sem DLL baixada, servidores/SDKs locais ou controle de hardware |
| Relatório HTML/JSON (`ReportBuilder`) | Adaptar futuramente | Exportação explícita e local, com revisão de privacidade; nada exportado neste incremento |
| Configuração/chaves DPAPI (`AppSettings`) | Adaptar se necessário | Nenhum segredo necessário no incremento 1; usar Keychain se futuramente autorizado |
| Instalador/admin/atualização/release | Redesenhar | Executar como usuário comum; empacotamento, assinatura e notarização futuros, sem release agora |

## Limites reais de sensores e GPU Apple Silicon

A revisão dos headers públicos do SDK local encontrou `ProcessInfo.thermalState` (NSProcessInfo.h), que fornece estado categórico. Não há nele temperatura em graus ou consumo. A prévia usa apenas esse estado e não tenta traduzir categorias para números.

O header público Metal `MTLDevice.h` oferece `name`, `hasUnifiedMemory`, `supportsFamily`, `supportsRaytracing`, `recommendedMaxWorkingSetSize` e `currentAllocatedSize`. O último representa alocações do **processo atual**; o working set recomendado é um orçamento. Nenhum deve ser rotulado como utilização global de GPU ou VRAM em uso por todos os aplicativos. Memória unificada não deve ser somada à RAM como memória física adicional. O incremento 2 consulta nome, memória unificada, suporte RT e orçamento recomendado sem renderizar ou rodar benchmark; não lê currentAllocatedSize e não apresenta utilização global. Suporte deve ser consultado por dispositivo, sem fixar tabelas por nome de chip. Esta é uma avaliação dos APIs selecionados, não alegação de que toda telemetria concebível seja impossível.

APIs públicas consideradas: Mach host_statistics/host_statistics64/host_page_size, sysctlbyname (chaves read-only), libproc proc_listallpids/proc_pidinfo, getfsstat(MNT_NOWAIT) com filtro MNT_LOCAL/MNT_DONTBROWSE, Foundation ProcessInfo, Metal e SwiftUI. A semântica de retorno em cache foi conferida também no manual local `getfsstat(2)`. Referência verificável local: `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/` e headers dos frameworks Foundation e Metal. Nenhum código upstream foi executado para esta avaliação.

## Plano

1. **Entregue:** pacote nativo arm64, dashboard e processos somente leitura, unidades explícitas, estado indisponível/parcial, testes determinísticos e smoke test limitado no Mini.
2. **Incremento 2 entregue:** fontes injetáveis e 20 testes, incluindo falhas/permissões; identidade/capacidades Metal sem workload; volumes locais; cache de inventário de 30 s e polling de 5 s apenas com janela ativa/atualização ligada. Histórico gráfico de CPU ainda não implementado.
3. **Validação visual futura autorizada:** abrir GUI no Mini, verificar layout, acessibilidade, pausa/retomada e consumo em repouso. Ainda não realizada porque execução GUI ficou fora do escopo.
4. **Empacotamento futuro:** projeto/bundle `.app`, identidade própria do fork, assinatura/notarização e distribuição somente após autorização para certificados/custos/release. Sem instalador privilegiado.
5. **Validação M5 futura autorizada:** compilar/rodar no hardware M5 real, verificar APIs/OS/permissões e consumo. A execução atual no M1 não certifica M5, OS mínimo ou distribuição. Não acessar outro computador neste trabalho.

Stress, overclock, purge, kill automático, fan control, drivers/RGB e alterações de settings permanecem excluídos. Não abrir PR no upstream.

## Validação visual proposta — depende de aprovação

No próprio Mini M1, abrir uma única instância do executável próprio recém-compilado como usuário comum durante no máximo três minutos; verificar conteúdo/rolagem a 100% e fonte ampliada, tema do sistema, VoiceOver/rótulos, datas e textos indisponíveis. Usar somente a pausa da UI e a alternância normal de foco para confirmar que a coleta para e que a CPU aguarda nova referência na retomada. Conferir visualmente Metal e volumes **já montados**, sem conectar/montar/desmontar dispositivos. Observar consumo em repouso do próprio app pelo Monitor de Atividade, sem encerrar processos ou gerar carga, e fechar o app ao terminar. Se qualquer permissão extra for solicitada, parar sem conceder. Não instalar, registrar login item, mudar settings, testar M5 nem gerar release. Uma tentativa posterior iniciou e encerrou nosso processo, mas o serviço nativo de interface falhou sem captura. Layout/acessibilidade/pausa visual continuam não confirmados; ver [VISUAL-CHECK.md](VISUAL-CHECK.md).
