# Revisão visual manual no Mini

O serviço nativo de inspeção continua sem fornecer imagem ou árvore de acessibilidade do app. A listagem de aplicativos responde, mas não comprova disponibilidade da captura. Não há validação visual confirmada.

Foi preparado localmente, fora do repositório e sem instalação, o bundle **ResetExplodeMac-Preview.app**, na pasta de trabalho `task-3` (ao lado do checkout `ResetExplode`). Ele contém apenas o executável próprio arm64 do commit `41c98f9`, Info.plist, MIT e créditos. SHA-256 do executável: `73cd110e6a40ad38524a69971646e17bf5bd4bc6ada893a747de3b4ff4d349dc`. O bundle é de avaliação local, sem assinatura de distribuição ou notarização; não foi enviado ao GitHub nem publicado em release. Foi criado sem sobrescrever uma pasta existente e não foi aberto durante sua preparação.

## Passo mínimo para o usuário

1. No próprio Mini, abrir uma vez `ResetExplodeMac-Preview.app` pelo Finder. Se houver alerta de segurança/privacidade ou bloqueio do macOS, **parar sem aceitar ou contornar**. Não usar “Abrir mesmo assim”, remover quarentena ou mudar ajustes de segurança.
2. Se a janela abrir normalmente, conferir por até três minutos o dashboard, a rolagem, os rótulos e os avisos de dados indisponíveis. O nome/capacidades Metal não representam utilização global; volumes APFS não devem ser somados. Zero real de espaço disponível pode aparecer como zero.
3. Desligar somente o interruptor de atualização do próprio app por cerca de 15 segundos: o horário deve ficar parado e indicar pausa. Religar: a CPU deve aguardar a nova amostra e depois atualizar. Não executar testes de carga, conectar/montar volumes, alterar settings nem operar o M5.
4. Fechar apenas esta instância pelo menu do app ou `Command-Q`. Se desejar devolver evidência, capturar somente a janela do port, evitando nomes de processos/volumes ou outros dados que não queira compartilhar.

Acessibilidade por teclado/VoiceOver e observação contínua de repouso continuam pendentes; não ativar ou alterar configurações do sistema apenas para esta revisão. Os 20 testes e o build aprovados não substituem a inspeção visual.
