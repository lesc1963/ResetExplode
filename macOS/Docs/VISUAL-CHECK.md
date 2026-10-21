# Tentativa de validação visual no Mini — não confirmada

Data: 2026-10-21 UTC. Código do port: commit `41c98f9a84cb77f5e1d6d88b5bdf5efb42804c04`, Mac Mini M1/macOS 27.0.1. Escopo autorizado: uma instância do código próprio por até três minutos, sem instalação, permissões extras, workloads, rede ativa, mudanças de segurança ou acesso ao M5.

## Revisão antes da execução

O executável próprio recém-compilado foi conferido como Mach-O arm64, ligado apenas a frameworks Apple e runtime Swift. O source do alvo macOS permanece somente leitura; não chama instaladores, executáveis Windows, rede, shell ou ações de alteração de processos/sistema. Não foi executado código original Windows ou de terceiros.

SHA-256 do executável revisado e da cópia temporária, idênticos:

`73cd110e6a40ad38524a69971646e17bf5bd4bc6ada893a747de3b4ff4d349dc`

A ferramenta nativa não reconheceu o executável SwiftPM solto (`Invalid app`). Foi criado apenas um wrapper `.app` em `/tmp/ResetExplodeVisualCheck.app`, com Info.plist mínimo e uma cópia exata do executável próprio. Não foi copiado para Applications nem instalado, distribuído ou assinado com certificado. Nenhuma proteção macOS foi alterada.

## Resultado observado e bloqueio

A chamada `cua.getApp('/tmp/ResetExplodeVisualCheck.app')` ficou sem responder e terminou com **`Sky Computer Use native pipe closed before response`**, após 415,967 s. Não retornou imagem, árvore de acessibilidade ou confirmação da janela. O atraso da chamada não representa duração confirmada de execução do app.

Uma consulta posterior `ps`, filtrada exclusivamente pelo caminho do executável próprio, confirmou a instância PID **51681**, com tempo de execução **00:35**, CPU **0,0%** e RSS **123792 KiB** (aproximadamente 121 MiB), no momento da observação. Isso confirma início do processo e uma amostra pontual; não valida interface, atividade do timer, desempenho sustentado ou ausência de alertas. Nenhum prompt de segurança/privacidade foi aceito.

Como a ferramenta de interface não respondeu, a sessão foi interrompida. Para limpeza, o caminho exato `/private/tmp/ResetExplodeVisualCheck.app/Contents/MacOS/ResetExplodeMac` foi novamente conferido para o PID 51681 antes de enviar SIGTERM **somente à nossa instância**. A consulta posterior confirmou que o processo terminou. Não foram encerrados outros processos. A duração observada do processo, incluindo essa limpeza, ficou abaixo de três minutos; não houve uma sessão visual de sete minutos.

A consulta inicial `ps` foi negada pelo sandbox; a consulta e a limpeza subsequentes seguiram pelo mecanismo normal de aprovação, com sucesso e sem `sudo` ou alteração de privilégios/configuração do host. Não há processo próprio conhecido pendente de encerramento. O wrapper e os produtos de compilação permanecem como artefatos temporários em `/tmp`.

## O que continua não verificado

- Layout, rolagem, tamanho ampliado de fonte, tema e legibilidade.
- Rótulos e navegação de acessibilidade/VoiceOver.
- Apresentação visual de indisponível versus zero real.
- Pausa/retomada e foco da janela no ciclo efetivo SwiftUI.
- Consumo em repouso ao longo de uma sessão visível.

Os 20 testes e o build do incremento 2 continuam aprovados, mas não substituem essas verificações visuais. **Nenhuma captura visual foi obtida; nenhuma imagem foi inventada ou retirada de outros aplicativos.** Nenhuma informação privada de outros apps foi capturada/publicada.

Bloqueio exato: inspeção/captura da janela do port pelo serviço nativo Computer Use, que encerrou o canal antes de responder. Estado final: processo iniciado e encerrado com sucesso; janela e validação visual **não confirmadas**. Não houve negativa de Gatekeeper ou de segurança conhecida; sem screenshot não se afirma ausência de alerta. Não foi tentado contornar qualquer proteção nem repetir uma abertura com resultado incerto.

Próximo passo: quando o serviço nativo de interface voltar a responder, repetir a sessão proposta na [matriz](PORTABILITY.md), no próprio Mini e com os mesmos limites. Nenhuma mudança no código foi inferida sem evidência da UI.
