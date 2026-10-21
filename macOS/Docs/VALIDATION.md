> Histórico do primeiro incremento. Evidência atual: [validação do incremento 2](VALIDATION-2.md).

# Validação do incremento 1

Data: 2026-10-21 UTC. Ambiente utilizado exclusivamente: este Mac Mini `Macmini9,1`, Apple M1, arm64, 8 CPUs físicas, 8 GiB de RAM; macOS 27.0.1 (26A434). Ferramentas existentes: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`, clang 2100.3.34.1), SDK macOS 27.0, Git 2.54.0 e GitHub CLI. Developer directory: `/Library/Developer/CommandLineTools`. Xcode completo e XCTest ausentes. Nenhuma dependência instalada.

## Resultados confirmados

| Verificação | Resultado |
| --- | --- |
| Identidade GitHub CLI e connector | `lesc1963`, ID 122786180 |
| Destino antes da criação | `lesc1963/ResetExplode` retornou 404; nada sobrescrito |
| Fork criado e origem conferida | `https://github.com/lesc1963/ResetExplode`, `isFork=true`, parent `GustavoReset/ResetExplode` |
| Base | `ce1d9b30518bbe75bb5e6cb792d1b1e365aaddd6`, v0.16.0 |
| Licença | MIT © 2026 Gustavo (GustavoReset), arquivo original sem alterações |
| `swift build --jobs 2` com caches temporários | Sucesso; executável SwiftUI compilado e linkado, sem executar a GUI |
| Arquitetura do executável (`file`) | Mach-O 64-bit executable arm64 |
| Bibliotecas vinculadas (`otool -L`) | Frameworks Apple e runtime Swift do sistema; nenhum componente Windows/terceiro |
| C bridge (`clang -fsyntax-only -Wall -Wextra -Werror`) | Sucesso, sem diagnósticos |
| Swift Testing | **5 testes passaram**, execução total 0,012 s, coleta local 0,011 s |
| Diff | Revisado, `git diff --check` sem erros; produtos de build ignorados |

Os comandos reproduzíveis de build e teste estão no [README](../README.md). O teste em `/tmp/resetexplode-validation-build` também compilou novamente o executável GUI, sem abri-lo. A biblioteca Swift Testing reportou versão 2084 e target `arm64e-apple-macos14.0`; isso é o target de compilação do runner, não evidência de execução em macOS 14. O sistema efetivamente usado foi o macOS 27.0.1 acima.

Testes executados:

1. Primeira amostra e amostra sem avanço de ticks retornam indisponível.
2. Carga usa o intervalo entre amostras, não a média desde o boot (caso de 20%).
3. Overflow de ticks UInt32 e tempo nice entram no cálculo (caso de 50%).
4. Extremos de 0% e 100% de CPU com amostras sintéticas, sem gerar carga.
5. Uma coleta real limitada e somente leitura: sistema, memória, capacidade de volume, PID/RSS, ordenação e aviso em caso de lista parcial/indisponível. Nenhum dado de processo foi exportado.

## Particularidades resolvidas do ambiente

- A rede do sandbox bloqueou inicialmente consultas `gh`; as consultas e a criação/clone seguiram pelo mecanismo normal de aprovação, com sucesso.
- O sandbox impediu o manifest evaluator do SwiftPM (`sandbox_apply: Operation not permitted`). A compilação/teste recebeu aprovação normal; nenhuma política do host foi modificada.
- Caches padrão estavam fora do workspace. Usaram-se caches temporários explícitos.
- O SDK oferece macro SwiftUI `State`, mas seu plugin não está presente nas Command Line Tools. O estado da UI usa `ObservableObject`/`Published`/`StateObject`, compilados com sucesso.
- XCTest ausente: os testes usam Swift Testing já instalado; foi necessário passar explicitamente o caminho de seu plugin Apple ao compilador.
- Metadados Finder/File Provider no bundle gerado dentro do workspace impediram assinatura ad hoc dos testes. Usou-se um diretório de build em `/tmp`, sem remover metadados dos arquivos do usuário e sem alterar segurança.
- O linker avisa sobre diretórios opcionais inexistentes `CommandLineTools/Developer/usr/lib` e `Developer/Library/Frameworks`. Build/link e os testes concluíram com sucesso. Nenhum caminho global foi criado ou alterado.

## Limites

**M5 não validado.** Nenhum outro computador acessado. Nenhuma GUI aberta ou validada visualmente. Sem execução em macOS 14; esse é apenas o mínimo declarado. Sem benchmark, stress, instalador, driver, RGB, overclock, purge, kill, alteração de settings ou serviço. Nenhum binário original ou hook de terceiro executado. Sem release, instalação, assinatura de distribuição, notarização ou PR no upstream. A assinatura ad hoc automática do runner de testes é local e não constitui distribuição do app.

Próximo passo de implementação: fontes injetáveis e testes de falha, inventário Metal de capacidades sem workload, múltiplos volumes e histórico leve. Abertura da GUI no Mini e testes em M5 devem receber escopo próprio antes da execução. Não existe bloqueio restante para o incremento de código entregue; testes visuais, hardware M5 e empacotamento continuam pendentes.
