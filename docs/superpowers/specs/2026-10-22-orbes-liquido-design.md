# Orbes de vida e recurso: líquido estilo PoE2 — design

Data: 2026-10-22. Aprovado em conversa com o usuário a partir das prévias
`.superpowers/brainstorm/4117-1792723670/content/orbs-estilos-v5.html`.

## Intenção

O conteúdo dos orbes (vida à esquerda, recurso da classe à direita) está feio: cores chapadas
e animação de "disco girando". O usuário quer o líquido do Path of Exile 2 girando dentro do
vidro: fundo escuro e profundo, fios claros que se enroscam devagar, vidro com reflexo. A
moldura (arte do HUD) não muda.

O addon é para outros jogadores também, então o visual é escolhido na configuração, entre
quatro estilos.

## Objetivos

- Líquido com movimento de fluido real: animação quadro a quadro em loop (não uma textura
  girando), lenta.
- Quatro estilos na configuração do ObsidianUI (página "ObsidianUI" do painel do jogo):
  - **A — Redemoinho** (padrão): fios finos em espiral para o centro.
  - **B — Energia**: espiral mais forte, núcleo que pulsa devagar, bolhas de luz subindo.
  - **C — Névoa**: formas largas e lentas, como fumaça.
  - **D — Parado**: visual do A congelado; nada se mexe, só o nível muda.
- Parte vazia do frasco transparente (mostra o mundo atrás) em qualquer nível.
- Cores profundas: corpo quase preto do tom, fios claros por cima, fundo do líquido mais
  escuro que o topo.
- Vidro: reflexo em meia-lua no alto à esquerda, sombra interna na borda, linha de luz na
  superfície que ondula devagar.
- Trocar de estilo na configuração aplica na hora (sem /reload).

## Não-objetivos

- Mudar a moldura/arte do HUD, o texto dos orbes (porcentagem e valores) ou o tamanho.
- Efeitos de dano/cura (piscar ao perder vida, etc.).
- Escudo de energia, absorção ou cura prevista dentro do orbe.

## Anti-objetivos (falha mesmo se "funcionar")

- Parecer cetim/tecido brilhante, cores claras e chapadas (a primeira v3 caiu nisso).
- Movimento rápido ou nervoso.
- Fundo preto na parte vazia.
- Qualquer conta em Lua com valores de vida/recurso (podem ser "secretos" em combate): o
  nível continua vindo só de `StatusBar:SetValue` e âncoras.
- Pedir ao jogador para digitar comando ou mexer em configuração do jogo para funcionar.

## Restrições

- Cliente WoW Forever (tipo "camelot", família Mainline). Verificar APIs no
  `Gethe/wow-ui-source`, branch `forever`, antes de usar algo novo.
- Eventos novos: conferir o nome na documentação gerada da API (um evento inexistente quebra
  o carregamento do arquivo; o barramento `ns.On` já ignora, mas o código não pode depender
  dele).
- Texturas novas só aparecem depois de fechar e abrir o jogo (avisar o usuário).
- Testes em `tests/` (pytest + lupa, stub `tests/wowstub.lua`), TDD; prévia visual com
  `tools/preview_render.py` antes de reportar.

## Como foi decidido (pelo usuário)

- Estilo do PoE2: líquido girando dentro do vidro.
- Quatro estilos (A, B, C, D) na configuração, D sem movimento.
- Movimento mais lento que a v4 (a v5 tem o ritmo aprovado).
- Parte vazia transparente.

## Decisões minhas (o usuário pode revisar)

- **Padrão: estilo A.** Os dois orbes (vida e recurso) usam sempre o mesmo estilo.
- **Ritmo (aprovado na v5):** 7 quadros/s na folha de 64 quadros (loop de ~9 s), com
  transição suave entre quadros consecutivos; giro do líquido 0,05 rad/s (A), 0,08 (B),
  0,02 (C); segunda camada girando ao contrário a ~60% da velocidade (A e B); onda da
  superfície lenta; pulso do B a ~0,13 Hz; bolhas do B sobem devagar.
- **Cores:** líquido gerado em cinza e tingido no jogo, para servir a qualquer recurso. Cada
  cor do orbe vira três tons: fundo (quase preto), corpo e fios. Vida: fundo (12,0,2), corpo
  (62,2,7), fios (230,46,30), linha (255,150,110) em 0–255. Mana: fundo (0,3,16), corpo
  (5,22,80), fios (44,130,245), linha (170,220,255). Para os demais recursos (raiva, energia,
  foco, poder rúnico...) os tons são derivados da cor atual em `Data.ORB_COLORS`/
  `PowerBarColor` pela mesma proporção (fundo ≈ 6–10% da cor, corpo ≈ 30–40%, fios ≈ a cor
  clareada). Vida e mana usam os valores acima exatamente.
- **Texturas** (geradas por `tools/orb_fluid.py`, exportadas por `tools/export_textures.py`
  para `ObsidianUI/Media` + `manifest.lua`):
  - `fluid_a`, `fluid_b`, `fluid_c`: folhas 8×8 de quadros 128 px (1024×1024), cinza no
    alfa, loop perfeito. D usa `fluid_a` congelado num quadro fixo.
  - `orb_glass`: reflexo em meia-lua + brilho na borda de baixo (aditivo).
  - Corpo do líquido: esfera escura em cinza (pode reaproveitar/ajustar a `liquid` atual).
  - Superfície: faixa de onda e linha de luz (pode reaproveitar/ajustar a `wave` atual).
  - Sombra interna: a `vignette` atual.
  - Bolhas do B: um ponto de luz suave pequeno.
  - Texturas antigas que ficarem sem uso (`swirl`) são removidas.
- **Montagem no jogo** (camadas de baixo para cima, todas com a máscara circular):
  1. Nada atrás da parte vazia (o fundo escuro atual sai).
  2. Corpo: o `StatusBar` vertical com a textura da esfera tingida no tom de corpo; o nível
     vem do `SetValue`.
  3. Um quadro de recorte ancorado do topo da barra preenchida até o fundo do orbe, com
     `SetClipsChildren(true)`: tudo do líquido fica dentro dele, então o líquido acompanha
     o nível sem conta em Lua. Dentro: a folha de quadros em tamanho cheio do orbe (um
     pouco maior, para o giro não mostrar canto), modo aditivo, tingida na cor dos fios;
     duas texturas alternando quadros para a transição suave; giro contínuo; segunda camada
     (A e B) com outro quadro de partida e giro contrário; núcleo pulsante e bolhas (B);
     escurecimento para o fundo.
  4. Superfície: onda + linha de luz presas ao topo da barra preenchida (como hoje).
  5. Sombra interna e vidro por cima de tudo (vidro sobre o frasco inteiro, inclusive a
     parte vazia).
  6. Texto (inalterado).
- **Configuração:** uma lista "Estilo dos orbes" (A Redemoinho, B Energia, C Névoa,
  D Parado) na página do ObsidianUI, salva em `ObsidianUIDB` (chave nova, padrão "a").
- **Desempenho:** a animação só roda com o orbe visível; no D não há `OnUpdate`.

## Deixado para quem constrói

- Como girar (animação de rotação nativa ou `SetRotation`), desde que funcione junto com a
  troca de quadros por coordenadas de textura — verificar no cliente.
- Se o recorte por `SetClipsChildren` respeita a máscara circular; se não, outra forma de
  limitar o líquido ao nível sem conta em Lua.
- Ajustes finos de alfa/tons para bater com a prévia v5 no jogo (o jogo pode renderizar o
  aditivo diferente do navegador).
- Organização do código (pode continuar em `HUD/Orbs.lua`).

## Pronto quando

- Os quatro estilos aparecem no jogo como na prévia v5, trocáveis na configuração na hora.
- Parte vazia transparente; nível acompanha vida/recurso em combate sem erros.
- Testes cobrindo: estilo salvo/aplicado, D sem `OnUpdate`, cores derivadas por recurso,
  folhas geradas com o tamanho/loop certos, nenhuma conta em Lua sobre valores de unidade.
