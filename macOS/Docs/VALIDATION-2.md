> Registro posterior: [tentativa visual no Mini](VISUAL-CHECK.md), com processo encerrado e inspeção visual não confirmada por falha do serviço de interface. O resultado abaixo registra o build/testes anteriores à tentativa.

# Validação do incremento 2

Data: 2026-10-21 UTC. Ambiente permanece exclusivamente este Mac Mini M1 (`Macmini9,1`, arm64, 8 GiB), macOS 27.0.1 (26A434), Apple Swift 6.4 e Command Line Tools existentes. Base deste incremento: commit `c039d3b0a3bceef4f5c855cfe2644dd418b9dd32` da branch `macos-port`. Sem instalação de ferramentas/dependências. M5 e macOS mínimo declarado 14 continuam sem execução real.

## Entregue e verificado

- `SystemDataSource` injetável e tempo monotônico fornecível nos testes, com amostragem serial no actor. Fonte nativa isolada de normalização/cálculos/cache. Os testes sintéticos não tocam hardware nem aguardam timers.
- CPU por diferença de ticks UInt32 com wrap, incluindo nice; sem amostra inicial falsa, sem divisão por zero. Falha, retomada explícita, relógio regressivo ou intervalo maior que 15 s reiniciam a referência. O valor representa a média do intervalo, não clock, temperatura ou utilização de um único núcleo.
- Memória: free_count já inclui speculative_count; compressed representa páginas físicas do compressor. Campos não são somados para inventar memória usada/pressão. Leituras com capacidade zero ou categorias maiores que a memória física são rejeitadas. Zero livre/comprimida realmente retornado continua válido. A ponte verifica page size e tamanho da estrutura retornada antes de ler o compressor, evitando aceitar campos não fornecidos como zero.
- Metal: `MTLCopyAllDevices`, nome, memória unificada, suporte a ray tracing e orçamento recomendado. Só metadados públicos; nenhuma fila, pipeline, shader, buffer ou carga GPU. Orçamento ausente/zero vira indisponível, não uso zero. Suporte `false` conhecido fica distinto de capacidade desconhecida.
- Múltiplos volumes locais montados e navegáveis: `getfsstat(MNT_NOWAIT)`, sem caminhos de rede ou varredura de conteúdo. Leitura em cache do kernel, marcada na interface; não força atualização nem espera por filesystems remotos. Capacidade/available convertidos de blocos com verificação de overflow, sentinelas indefinidas e available <= total. Espaço realmente zero continua zero. Não somar volumes APFS como capacidade física independente.
- Ausência, permissão negada, inventário parcial e lista vazia têm estados separados. Falha na renovação de inventário remove valores antigos. Processos/volumes são deduplicados e limitados a 4096/256; não se coletam argumentos nem se exportam listas.
- UI com rolagem para acomodar inventários; estado de pausa e horário separado de consulta de Metal/volumes. Compilada, ainda sem avaliação visual.

## Build e testes

Comandos completos no [README](../README.md). A validação usa build/caches temporários e o plugin Swift Testing Apple já instalado, conforme o histórico do [primeiro incremento](VALIDATION.md). Nenhuma configuração de segurança foi alterada.

- `swift test --jobs 2 --disable-xctest ...`: **20 testes passaram**, total 0,012 s na rodada final, incluindo uma coleta nativa limitada de 0,011 s; compilou e linkou também o executável SwiftUI sem abri-lo.
- `clang -fsyntax-only -Wall -Wextra -Werror`: sucesso, sem diagnósticos na ponte C.
- `swift build --jobs 2 ...`: sucesso independente após os testes, em 3,09 s com cache.
- `file`: executável GUI Mach-O arm64. `otool -L`: Metal/frameworks Apple/runtime Swift; sem bibliotecas Windows ou de terceiros.
- `git diff --check`: sem erros; diff revisado. MIT/créditos preservados, nenhum workflow/CI/release acrescentado.
- Permanecem avisos do linker sobre diretórios opcionais ausentes das Command Line Tools; não impedem compilação, link ou testes.

Cobertura: matemática de CPU (4 casos originais); smoke local; erros de permissão/indisponibilidade em todas as categorias; recuperação de CPU após falha; intervalo longo/relógio regressivo; reset na retomada; cache, invalidação e recuperação de inventários; relógio regressivo no cache; inventários vazios; memória inválida versus zeros reais; múltiplos volumes com falha individual/dados inválidos/duplicação; overflow/sentinelas de blocos; Metal com campos ausentes; processos parciais/duplicados/limite; dados de sistema ausentes/inválidos; política de polling; limite de volumes. Nenhum dado de processo, nome de volume ou identificador de dispositivo real foi registrado no repositório.

## Revisão do impacto da coleta

O timer aguarda cinco segundos **após** terminar cada amostra; não cria amostras concorrentes. Pausa do usuário ou cena inativa cancela o timer; uma leitura síncrona já em andamento pode concluir, mas sua tarefa cancelada não publica resultado. A retomada exige nova referência de CPU. A política de atividade/pausa foi testada isoladamente; o ciclo de vida efetivo SwiftUI ainda depende da sessão visual aprovada.

Metal e montagens consultam a fonte no máximo uma vez a cada 30 s por janela/coletor durante operação normal; o cache conserva o horário da consulta e também mantém erros até a próxima tentativa, sem retry apertado. Metadados e buffers são limitados, liberados e não acumulam histórico. Processos usam aproximadamente 320 KiB de buffer Swift mais 16 KiB de PIDs na ponte por amostra, além de nomes/modelos; volumes usam até cerca de 264 KiB na ponte Swift mais o buffer statfs temporário. A lista de dispositivos Metal fica em cache como valores simples, sem reter recursos GPU.

Duração de uma única coleta local é somente evidência de execução leve naquele instante. Não demonstra consumo sustentado de CPU/RSS, comportamento da janela, custo de driver Metal em outras máquinas ou garantia de latência máxima. Não foi feito perfil de GUI ou benchmark. O próximo passo aprovado pode observar repouso e pausa por até três minutos, conforme a proposta na [matriz](PORTABILITY.md).

## Ainda fora do port

Uso global GPU, °C, clocks, watts, fans, SMART, RAM por módulo, FPS global/overlay, jogos/launcher, gargalo, rede ativa, bateria, inventário serial, exportação, histórico gráfico e empacotamento/distribuição não foram implementados. Stress/benchmarks, overclock, purge, kill automático, ajustes de sistema, fan control, drivers e RGB continuam excluídos. Sem GUI aberta, acesso a M5, instalação de app, serviço, mudança em produção, release ou PR upstream. Não há bloqueio restante para este incremento de código; validação visual requer aprovação separada.
