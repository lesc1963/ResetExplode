# Reset Explode para macOS — incremento 1

Port nativo independente em desenvolvimento, derivado de [GustavoReset/ResetExplode](https://github.com/GustavoReset/ResetExplode), snapshot `ce1d9b30518bbe75bb5e6cb792d1b1e365aaddd6`, v0.16.0. Copyright original © 2026 Gustavo (GustavoReset), licença [MIT](../LICENSE) preservada. O código Windows permanece como referência histórica; nenhum binário, driver ou pacote dele é usado pelo alvo macOS.

Alvo: Apple Silicon arm64, incluindo futuro teste em Mac M5; mínimo declarado macOS 14 e Swift 6.0. A compatibilidade com o M5 e com macOS 14 **não foi validada em hardware/OS reais**. Esta prévia ainda não é um app distribuível, assinado ou notarizado.

## Implementado

- Interface SwiftUI com CPU agregada por intervalo, memória física/livre/ativa/wired/comprimida, capacidade e espaço disponível do volume do usuário, modelo/chip/macOS, CPUs lógicas, uptime e estado térmico categórico.
- Lista de processos visíveis, PID, nome curto e RSS, ordenada por RSS. Sem argumentos de linha de comando, caminhos de executáveis, usuário ou exportação automática. Leituras podem ser parciais pelas permissões ou por processos que terminaram.
- Atualização a cada 5 segundos, com opção de pausar. A primeira leitura de CPU aguarda a segunda amostra; erros não viram métricas zero. Sem comandos de shell ou processos filhos.
- GPU, temperaturas em °C, clocks, potência e ventoinhas explicitamente indisponíveis nesta prévia.

Memória livre usa `free_count` do Mach, que já inclui páginas especulativas. Memória comprimida corresponde ao tamanho físico do compressor. As categorias exibidas não formam uma partição completa da RAM e não equivalem à pressão de memória. RSS inclui páginas compartilhadas e não deve ser somado como consumo físico total. Capacidade APFS pode ser compartilhada; espaço disponível não é saúde, desgaste nem espaço purgeable prometido.

## Arquitetura

`ResetMac` (SwiftUI, estado isolado no MainActor) → protocolo assíncrono `SnapshotCollecting` → `MacCollector` (actor, amostragem serial fora do MainActor) → `CSystem` (pequena ponte C para Mach, sysctl e libproc públicos) e Foundation. Modelos imutáveis `Sendable`; lógica de diferença de ticks testada isoladamente. A ponte limita o inventário a 4096 processos por amostra e libera memória/portas Mach. Não há dependências SwiftPM externas, scripts de build, plugins ou acesso à rede pelo app.

## Compilar e testar

A partir deste diretório, com Swift 6 já instalado (Xcode ou Command Line Tools):

```sh
swift build --jobs 2
swift test --jobs 2 --disable-xctest
```

Isso compila um executável SwiftUI no diretório retornado por `swift build --show-bin-path`; não instala nem abre o app. Os testes usam Swift Testing da própria toolchain. Nesta versão das Command Line Tools, é necessário informar explicitamente o caminho do plugin de testes Apple. No Mini, a validação usou estes comandos, com caches e build de testes em `/tmp` para evitar restrições de cache e metadados Finder/File Provider do workspace:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/resetexplode-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/resetexplode-module-cache \
swift build --jobs 2 --cache-path /tmp/resetexplode-spm-cache --manifest-cache none \
  -Xswiftc -module-cache-path -Xswiftc /tmp/resetexplode-module-cache

CLANG_MODULE_CACHE_PATH=/tmp/resetexplode-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/resetexplode-module-cache \
swift test --jobs 2 --disable-xctest --scratch-path /tmp/resetexplode-validation-build \
  --cache-path /tmp/resetexplode-spm-cache --manifest-cache none \
  -Xswiftc -module-cache-path -Xswiftc /tmp/resetexplode-module-cache \
  -Xswiftc -plugin-path \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

O comando de testes executa somente código próprio; XCTest não está instalado neste Mini. O sandbox de execução do agente exigiu aprovação normal para o avaliador de manifests do SwiftPM; nenhuma configuração de segurança do Mac foi alterada. Os caminhos das ferramentas acima correspondem às Command Line Tools selecionadas neste Mini e devem ser ajustados ao usar Xcode completo.

Não executar o binário GUI, benchmarks, scripts Windows, instaladores ou drivers como parte desta validação. Não há release, `.app`, entitlements privilegiados, serviço de background ou autostart. O workflow Windows herdado só pode executar no repositório original; nenhum CI novo é acionado no fork.

Ver [matriz e plano](Docs/PORTABILITY.md) e [registro de validação](Docs/VALIDATION.md).
