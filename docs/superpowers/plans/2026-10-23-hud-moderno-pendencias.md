# HUD "Moderno" — o que ainda falta

Estado em 2026-10-23: fase 1 implementada (commits 19cc6e6..7dee33b, 278 testes passando).
Nada foi testado no jogo ainda (servidor do Forever fechado). Design:
`docs/superpowers/specs/2026-10-23-hud-moderno-design.md`. Protótipo aprovado: sketch HTML
(scratchpad `sketch/index.html`, servido em http://127.0.0.1:8766).

## Fase 2 — Modo de edição (próximo)
- Botão nas configurações (e /obui editar) que mostra uma caixa tracejada com nome em cada elemento:
  jogador, alvo, alvo do alvo, foco, pet, barra de ações, barra de cast, minimapa, menu, barras
  verticais, buffs, inventário.
- Arrastar com o mouse; roda do mouse muda o tamanho (0,5–2,0, passos de 5%).
- Painel com linhas/colunas da barra e botão "Restaurar".
- Posição e tamanho salvos por elemento em `ObsidianUIDB` (ex.: `db.layout[chave] = { ponto, x, y, escala }`).
- Só fora de combate (frames seguros); sair do modo de edição ao entrar em combate.
- Os layouts padrão continuam valendo quando não há posição salva.

## Fase 3 — Inventário Moderno
- Janela larga, preto fosco translúcido: personagem à esquerda (modelo, 8+8 slots, 3 armas, nível
  de item, abas Atributos/Reputação/Moedas), mochila à direita (busca, ordenar, abas de filtro,
  grade 9×7 com borda de raridade e pilhas, barra de rolagem, 5 bolsas, espaços livres, dinheiro).
- Mesma lógica do inventário atual (BagGrid, Stats, Filters), só o visual e o layout novos.
- Opção azul também.

## Ajustes pendentes da fase 1
- Gemas de recurso de classe (combo, runas, poder sagrado...) ainda usam a arte de pedra no Moderno.
- Buffs do jogador ficam no topo central; no sketch apareciam embaixo do quadro do jogador
  (decidir com o usuário).
- Ícones do menu: conferir no jogo (no preview saem como quadrados escuros por limitação do
  simulador).
- Quadros de grupo e raide no estilo Moderno (planejados também para a HUD de pedra).
- Nameplates no estilo Moderno.

## Verificar no jogo quando o servidor voltar
- Reiniciar o jogo uma vez (texturas novas não carregam com /reload).
- Trocar para o Moderno e aceitar a recarga; voltar para Pedra.
- Barra de ações: atalhos 1–=, segunda linha, linhas/colunas mudando ao vivo, botões fora da grade
  sem atalho.
- Barra de cast: zona verde do ping, marca da fila, tempo; em combate não pode dar erro.
- Alvo do alvo embaixo do alvo sem sobrepor a barra de cast/debuffs do alvo.
- Anel arcano girando; ligar/desligar.
- Minimapa: relógio, correio, rastreamento e calendário nos lugares novos.
- Menu: todos os botões abrindo as janelas (sem taint).
