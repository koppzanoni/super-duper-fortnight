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
Barras de dados (FEITO): experiência + descanso e reputação acompanhada (cor por reputação),
texto sempre/ao passar o mouse/nunca, altura, liga/desliga, modo de edição; a barra de ações sobe
quando as duas barras não cabem embaixo dela.
Grupo e Raide (FEITO: HUD/GroupFrames.lua): grupo com os quadros Moderno pequenos empilhados
(some em raide); raide em células por subgrupo (linhas ou colunas), cor da classe, nome, linha de
mana, ícone de tanque/curador, Morto/Desconectado em cinza, borda na cor do debuff dissipável,
apagado fora de alcance (UnitInRange é secreto: SetAlphaFromBoolean); largura/altura; modo de teste
(painel, /obui teste [grupo|raide], o modo de edição mostra o grupo quando sozinho; combate encerra);
esconde PartyFrame/CompactPartyFrame/CompactRaidFrameManager/Container quando ligados.
Também feito: você no grupo (opção), grupo em células do raide (opção), até 3 debuffs por membro
(liga/desliga), marcador de raide, ícone da checagem de prontidão (some 6 s depois), ferramentas de
raide (HUD/RaidTools.lua: Pronto?, contagem de 10 s, 8 marcadores + limpar; só líder/assistente;
movível; liga/desliga). Ainda não: marcadores no chão (exigem macro segura).
Nameplates (FEITO: HUD/Nameplates.lua): por cima das placas do jogo (UnitFrame com alpha 0, hook
em SetAlpha), barra fina com cor por reação/classe, nome, % de vida, marcador, até 4 debuffs seus,
cast azul / cinza (não interrompível) — SetTimerDuration(UnitCastingDuration) quando aceitar, senão
pelos tempos, senão barra cheia; alvo com borda roxa (comparando a placa, não UnitIsUnit), outros
apagados; largura/altura; desligar devolve o visual do jogo. Placas proibidas (aliados em
instância) e a placa pessoal ficam como o jogo desenha. Falta: cor por ameaça (tanque), ícone de elite.
Chat (FEITO: HUD/Chat.lua): painel preto com borda fina englobando abas e mensagens (borda e
fundo do jogo com alpha 0), abas lisas com a ativa em branco e linha roxa (hook em
FCFTab_UpdateColors), caixa de digitar no próprio painel logo abaixo (ns.Pin), botões do lado
escondidos (opção), mensagens somem depois de N s (SetTimeVisible/SetFading, sem mexer em
configuração do jogo), botão de copiar com o texto sem códigos; janelas novas e de sussurro
pegam o visual (hook em FCF_OpenNewWindow/FCF_OpenTemporaryWindow).
Dicas (FEITO: HUD/Tooltip.lua): GameTooltip, ItemRefTooltip, ShoppingTooltip1/2,
EmbeddedItemTooltip num painel preto (NineSlice alpha 0, também depois de
SharedTooltip_SetBackdropStyle), borda na cor da raridade (TooltipDataProcessor Item) ou da classe
(Unit, nome também), linha "Alvo:", barra de vida fina; posição padrão / cursor / acima da barra de
informações; some sobre o mundo em combate (opção).
Rastreador de missões (FEITO: HUD/QuestTracker.lua): sem NineSlice e arte dos títulos, títulos
brancos com linha roxa (também em módulos novos, hook em Update), pendurado num suporte movível
("Missões", padrão: à esquerda das barras verticais ou sob o minimapa); recolher em combate e em
instâncias (abre de novo depois, a não ser que o jogador tenha recolhido).
Janelas da Blizzard (FEITO: HUD/Skins.lua): um pintor para os moldes ButtonFrame/PortraitFrame
(NineSlice, Bg, TopTileStreaks, PortraitContainer com alpha 0; painel preto; Inset mais escuro;
título branco; X simples; abas lisas com a selecionada branca e linha roxa via hook em
PanelTemplates_Select/DeselectTab). Janelas do jogo (personagem, amigos, PvE, conversa, missão,
comerciante, correio, provador, troca, banco, addons...) e as carregadas depois (talentos,
coleções, guia de masmorras, comunidades, profissões, macros, leilão, inspecionar, mapa) no
ADDON_LOADED. Conquistas ficam com a arte delas. Falta: botões e barras de rolagem dentro das
janelas ainda no estilo do jogo.
Recarga nos ícones (FEITO: HUD/Cooldowns.lua): os números do próprio jogo em cada Cooldown
(SetHideCountdownNumbers por quadro, sem mexer em configuração), mínimo de 1,5 s
(SetMinimumCountdownDuration), décimos nos últimos 3 s, fonte da HUD no tamanho do ícone; barras
de ação, itens das bolsas, seus buffs/debuffs e debuffs no alvo; só estiliza os quadros novos
entre uma mudança de ajuste e outra.
Cursor (FEITO: HUD/Cursor.lua): anel em volta do cursor e rastro de pontos que somem (texturas
cursor_ring/cursor_dot geradas em export_textures.py), cor das cores prontas (padrão: roxo da HUD),
só em combate (padrão), tamanho; some enquanto gira a câmera (IsMouselooking); por cima de tudo
(TOOLTIP), sem pegar o mouse; o OnUpdate só roda com anel ou rastro ligado.
Automação (FEITO: HUD/Automation.lua): vende lixo (C_MerchantFrame.SellAllJunkItems, avisa o valor)
e repara (guilda primeiro se a cota cobre, senão o seu ouro); aceita convite de amigo/guilda/Battle.net
(marca inviteAccepted antes de fechar a janela, senão ela recusa ao sumir); recusa duelos (opção);
aceita ressurreição de quem está fora de combate (espera o atraso do corpo); libera o espírito em campo
de batalha sem pedra da alma; pula cinemáticas e vídeos já vistos (seenCinematics é dado da conta, fora
dos perfis); saque rápido quando o saque automático vale; erros vermelhos escondidos em combate (opção,
UIErrorsFrame UI_ERROR_MESSAGE); tela de ausente (UIParent escondido, câmera girando, faixa preta com
modelo, nome, nível/classe/guilda, tempo; sai com tecla, combate, ou fim do ausente; nunca em instância).
Lembretes (FEITO: HUD/Reminders.lua): faixas pretas com ícone acima do centro (movível, "Lembretes"):
buff da classe faltando (mago/sacerdote/druida/guerreiro, versão de grupo conta; só se conhece a magia),
comida e frasco em raide (por nome: Bem Alimentado / Frasco, Phial), veneno do ladino ou óleo de arma
com menos de 5 min, durabilidade abaixo de 30%, 5 espaços livres ou menos. Só checa fora de combate
(auras podem ser secretas) e some em combate; revê a cada 15 s por causa das durações.
Classes (página FEITA: Classes/Classes.lua; seletor com a sua classe primeiro, as outras mostram
"Em breve" até ganharem o arquivo delas). Ladino (FEITO: Classes/Rogue.lua): linha do tick de energia
na barra de energia (só se a energia chega em saltos de 2 s; regeneração contínua não mostra nada),
pontos de combo acima da barra do alvo (opção, desligado), barras de Picar e Rasgar acima da barra de
cast (GetPlayerAuraBySpellID / GetUnitAuraBySpellID + GetAuraDuration -> SetTimerDuration; Rasgar só o
seu; movível "Temporizadores (Ladino)"), venenos acabando liga/desliga o aviso nos Lembretes.
Próximas classes, uma por commit: Guerreiro, Paladino, Caçador, Sacerdote, Cavaleiro da Morte, Xamã,
Mago, Bruxo, Monge, Druida (opções de cada uma no protótipo, CLASS_OPTS).
Falta: as outras classes na página Classes (+ modo de teste,
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

## Fase 3 — Inventário Moderno (FEITO)
Janela larga preta (Data.INV 1240 x 780; Core/Widgets.lua no visual Moderno): cabeçalho com nome,
nível, classe e fechar; personagem à esquerda (modelo com nível de item, 8+8 espaços e 3 armas na
moldura mod_slot pela raridade, abas Atributos/Reputação/Moedas, atributos em duas colunas);
bolsas à direita (busca e organizar, abas de filtro, grade de 9 colunas com barra fina, bolsas
equipadas, espaços livres, ouro). Mesma lógica de antes (BagGrid, Stats, Filters, atalhos).
A arte da janela de pedra foi aposentada (inventory_art.py e as texturas inventory, inventory_wing,
bag_slot, plate, scroll_thumb, stone_tile); a tag hud-pedra-final guarda tudo.
Falta: brilho atrás do modelo (como no protótipo), conferir no jogo.

## Ajustes pendentes da fase 1
- Buffs do jogador ficam no topo central; no sketch apareciam embaixo do quadro do jogador
  (decidir com o usuário).
- Ícones do menu: conferir no jogo (no preview saem como quadrados escuros por limitação do
  simulador).
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
- Inventário Moderno: abrir com C e B, arrastar pelo cabeçalho, fechar no X e no Esc, itens
  clicáveis, busca, organizar, abas de reputação e moedas abrindo as páginas da Blizzard.
- Nameplates: visual do jogo some de verdade (o hook de SetAlpha segura), cast andando em combate
  (qual dos três caminhos funcionou), alvo com borda roxa, nada de erro em instância.
- Chat: borda e fundo do jogo sumindo, abas recoloridas ao trocar, caixa de digitar no lugar ao
  abrir (Enter) e depois de arrastar o chat, botão de copiar, janela de sussurro nova com o visual.
- Janelas da Blizzard: abrir cada uma e ver se nenhuma ficou sem fundo ou com conteúdo escondido
  atrás do painel; abas trocando de cor; o mapa.
- Recarga nos ícones: números aparecendo nas barras, sem número na recarga global, décimos no fim.
- Cursor: reiniciar o jogo (texturas novas); anel seguindo o mouse sem atraso, some ao girar a
  câmera com o botão direito, rastro sumindo quando o mouse para.
- Automação: vender lixo e reparar (mensagem no chat), convite de amigo entrando no grupo sem a
  janela recusar, ressurreição, cinemática pulada na segunda vez, saque rápido, tela de ausente
  (/afk) saindo com tecla e voltando a interface inteira.
- Lembretes: ícones de comida/frasco/reparo/bolsa aparecendo (caminhos Interface\Icons), nome do buff
  batendo com a aura (Intelecto Arcano etc.), frasco reconhecido pelo nome no idioma do jogo.
- Ladino: o tick de energia existe neste cliente (saltos de 20 a cada 2 s) ou a linha nunca aparece;
  Picar/Rasgar andando em combate (GetPlayerAuraBySpellID pode devolver nil se a aura for secreta).
- Grupo/raide: aparecer e sumir ao entrar/sair de grupo e raide, ícone de função (textura
  UI-LFG-ICON-PORTRAITROLES), alcance apagando em combate, borda de dissipar, clicar = alvo,
  botão direito = menu; trocar de subgrupo em combate só reorganiza depois do combate.
- Marcadores (UI-RaidTargetingIcons), ícones de prontidão, debuffs nos quadros; ferramentas de raide:
  Pronto?, contagem e marcar o alvo funcionando sem erro.
