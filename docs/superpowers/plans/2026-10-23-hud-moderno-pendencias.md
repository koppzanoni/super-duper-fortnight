# HUD "Moderno" — o que ainda falta

Estado em 2026-10-23: fase 1 implementada (commits 19cc6e6..7dee33b). Depois o usuário aposentou
as outras HUDs: a Moderna é a única (pedra, Relicário e orbes removidos; recuperáveis pela tag
`hud-pedra-final`). O inventário antigo fica até o inventário Moderno substituí-lo.
Nada foi testado no jogo ainda (servidor do Forever fechado). Design:
`docs/superpowers/specs/2026-10-23-hud-moderno-design.md`. Protótipo aprovado: sketch HTML
(scratchpad `sketch/index.html`, servido em http://127.0.0.1:8766).

## Direção das configurações (aprovada 2026-10-23)
Modelo: NaowhUI (instalador guiado) + EllesmereUI (painel próprio modular, Unlock Mode, perfis).
Sem copiar o visual deles. Ordem: modo de edição -> painel -> perfis -> instalador; antes de
codar, protótipo do painel e do instalador no sketch.
- Painel próprio (janela no estilo do addon): barra lateral com módulos (Geral, Barras de ação,
  Quadros, Cast, Minimapa, Menu, Inventário, Perfis), liga/desliga por módulo, busca, mudanças ao vivo.
- Modo de edição estilo Unlock Mode: arrastar, redimensionar, snap em grade e em outros elementos,
  ancorar um no outro, igualar largura/altura, ajuste fino com as setas.
- Perfis: por personagem e por especialização (troca automática), presets, exportar/importar texto
  (completo ou por módulo).
- Instalador no primeiro login (/obui install): estilo (Pedra/Moderno), resolução/escala, função
  (DPS/tank/healer), classe, concluir com recarregar. Outro personagem: perfil carrega sozinho.

## Fase 2 — Modo de edição (FEITO: Core/Movers.lua + HUD/EditMode.lua, /obui editar)
Feito: arrastar, grudar (grade 8 px, centro, bordas/centros dos outros) com guias, roda = tamanho,
setas = 1 px (Shift 10), Centralizar, Restaurar, Restaurar tudo, sai em combate; salvo em db.layout.
Falta (vai para o painel): ancorar um elemento em outro, igualar largura, X/Y digitados, inventário
no sistema de movers (hoje tem o arrastar próprio).

### Plano original
- Botão nas configurações (e /obui editar) que mostra uma caixa tracejada com nome em cada elemento:
  jogador, alvo, alvo do alvo, foco, pet, barra de ações, barra de cast, minimapa, menu, barras
  verticais, buffs, inventário.
- Arrastar com o mouse; roda do mouse muda o tamanho (0,5–2,0, passos de 5%).
- Painel com linhas/colunas da barra e botão "Restaurar".
- Posição e tamanho salvos por elemento em `ObsidianUIDB` (ex.: `db.layout[chave] = { ponto, x, y, escala }`).
- Só fora de combate (frames seguros); sair do modo de edição ao entrar em combate.
- Os layouts padrão continuam valendo quando não há posição salva.

## Painel próprio (FEITO, primeira versão: Settings/Panel.lua, /obui)
Barra lateral em grupos, busca, mudanças ao vivo; opções já ligadas: cor (recarrega), escala,
modo de edição, teclas, restaurar posições, linhas/colunas, números das teclas, barras verticais,
anel arcano, zona de latência / ms / marca da fila, tamanho do inventário.
Falta (marcado "em breve" no painel): Barras de dados, Grupo, Raide, Nameplates, Chat, Rastreador de missões, Dicas, Janelas da Blizzard,
Cursor, Automação, Recarga nos ícones, Lembretes, Classes (+ modo de teste,
visibilidade por elemento, troca de perfil por conteúdo). Cada um entra como módulo novo.

## Perfis (FEITO: Core/Serialize.lua + Core/Profiles.lua, página Perfis)
Perfil por personagem, criar/copiar/excluir, troca ao vivo (cor pede recarga), um por
especialização (PLAYER_SPECIALIZATION_CHANGED / ACTIVE_TALENT_GROUP_CHANGED), por conteúdo
(solo/grupo/raide/JxJ, liga/desliga), presets (ObsidianUI, Compacto, Healer), exportar/importar
texto OBUI1 (tudo ou só posições; o leitor nunca executa código). Conteúdo do painel rola.

## Visual (FEITO: Core/Look.lua, página Visual)
Fonte (fontes do jogo), contorno, números (48.3K / 48.320 via AbbreviateNumbers/BreakUpLargeNumbers,
que aceitam valores secretos), textura das barras (Vidro/Suave/Lisa/Blizzard), cores de inimigo,
neutro, aliado e mana (cores prontas; seletor livre precisaria da janela de cores do jogo).

## Barra de informações (FEITO: HUD/InfoBar.lua)
FPS, ms, durabilidade, bolsas, ouro, amigos, guilda, hora; cada item liga/desliga; cores de alerta;
acima do menu por padrão, movível no modo de edição; atualiza por eventos e a cada 1 s.

## Instalador (FEITO: Settings/Installer.lua, /obui instalar)
Abre no primeiro login: boas-vindas, tamanho (1080p/1440p/4K -> escala), função (Cura = preset
Healer), cor (recarga só se mudar), concluir; Pular mantém tudo. Reabre pelo painel.

## Recursos de classe e Auras (FEITO)
Recursos: gemas Moderno (mod_gem_on/off), estilo barra com marcas (funciona com valores secretos),
cor por recurso, esconder fora de combate quando vazio, liga/desliga, movível/redimensionável.
Auras: moldura mod_slot (debuffs tingidos pelo tipo), tamanho, ícones por linha, buffs/debuffs liga/desliga.

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
- Trocar a cor (Preto/Azul) e aceitar a recarga.
- Barra de ações: atalhos 1–=, segunda linha, linhas/colunas mudando ao vivo, botões fora da grade
  sem atalho.
- Barra de cast: zona verde do ping, marca da fila, tempo; em combate não pode dar erro.
- Alvo do alvo embaixo do alvo sem sobrepor a barra de cast/debuffs do alvo.
- Anel arcano girando; ligar/desligar.
- Minimapa: relógio, correio, rastreamento e calendário nos lugares novos.
- Menu: todos os botões abrindo as janelas (sem taint).
