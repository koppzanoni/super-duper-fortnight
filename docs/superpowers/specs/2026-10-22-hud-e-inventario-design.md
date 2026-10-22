# Interface estilo Path of Exile 2 para WoW Forever: HUD de combate e inventário

Data: 2026-10-22
Escopo deste documento: **fase 1** do projeto (HUD de combate + inventário unificado). As outras fases (kit de janelas, janelas da Blizzard, grupo/raide, chat, tooltips) terão documentos próprios.

---

## 1. Intenção

O usuário acha a interface padrão do WoW **poluída e antiga**. Ele quer um addon que substitua a interface por algo **moderno, limpo e visualmente agradável**, no estilo do HUD de **Path of Exile 2**: pedra escura entalhada, ferro enegrecido e bronze envelhecido, com orbes de vida e mana nos cantos e uma moldura contínua no rodapé.

Inspirações citadas: o addon **GW2 UI** (como modelo de "addon que troca a interface inteira") e o **HUD do PoE 2** (como referência visual). A imagem de referência aprovada é `Meshy_AI_Dark Fantasy MMORPG HUD.png`, na raiz do projeto.

A meta de longo prazo é trocar **tudo** que existe na interface do WoW. Esta fase entrega a parte que o jogador vê o tempo todo: o HUD de combate e o inventário.

## 2. Objetivos, não-objetivos e anti-objetivos

**Objetivos da fase 1**
- HUD inferior único e contínuo: orbes, painéis de menu, barra de ações central e barra de XP.
- Todos os elementos de combate: alvo, alvo do alvo, foco, pet, conjuração, recurso de classe, buffs e debuffs, e minimapa.
- Funcionar bem para **todas as classes e especializações**, incluindo troca de forma do druida.
- Barras verticais opcionais na direita, ligadas e desligadas nas configurações do addon.
- Inventário unificado (equipamento + bolsas numa janela só).

**Não-objetivos nesta fase**
- Reskin das janelas da Blizzard: ESC, Configurações, guilda, LFG, coleções etc. Isso é a fase 2, com um "kit de janelas".
- Quadros de grupo e raide, nameplates, chat, tooltips e rastreador de missões. Ficam para uma fase posterior.
- Suporte a WoW Classic, Era ou Retail. O alvo é **só o WoW Forever**.

**Anti-objetivos (o que tornaria isso um fracasso mesmo funcionando)**
- **Visual poluído.** O usuário reclamou repetidamente de enfeites grandes demais. Enfeites devem ser contidos, e onde ele pediu "mínimo", como no minimapa, devem ser **só uma borda**.
- **Peças desencaixadas.** O rodapé deve parecer **uma peça só**. Não pode haver buracos de pedra vazia, peças flutuando, barras duplicadas nem moldura dupla entre peças vizinhas.
- **Formas quadradas e duras.** O usuário rejeitou versões "quadradas" e prefere silhuetas orgânicas, como na referência.
- **Reflexos artificiais nos orbes.** Bolhas de brilho ou meias-luas de reflexo foram rejeitadas. O vidro do orbe tem só volume (sombra interna).
- **Quebrar em combate.** Um HUD que trava, some ou não deixa usar habilidades em combate é inaceitável.

## 3. Restrições

- **Jogo:** WoW Forever. Segundo as fontes públicas, usa o motor de interface e a API **Mainline/Retail da era 12.x**, com Edit Mode, Cooldown Manager, medidor de dano e ping embutidos. Addons de Classic não carregam. A interface do Forever **não é 1:1 com a do Retail**: há painéis próprios, como o de talentos antigos na tecla Y e o de profissões na tecla K. O construtor deve conferir no jogo o nome real de cada frame antes de escondê-lo ou modificá-lo.
- **Valores secretos (12.x).** Desde a era Midnight, vários valores de combate, como a vida, viram "secret values": dá para passar para widgets nativos (`StatusBar:SetValue`, `FontString:SetText`), mas não dá para fazer conta nem comparação com eles em Lua. Isso afeta diretamente o orbe, que não pode calcular a altura do líquido em Lua. O construtor deve verificar como isso se comporta no Forever e usar widgets nativos (StatusBar vertical com máscara circular) para o preenchimento.
- **Combate e segurança.** Botões de ação usam os templates seguros (`SecureActionButtonTemplate`/`ActionButtonTemplate`). Nada de mostrar, esconder ou reposicionar frames protegidos em combate fora das regras de estado seguro.
- **Arte só em 2D.** Addons não carregam modelos 3D próprios. A interface é feita com texturas. O formato final deve ser aceito pelo cliente: TGA ou BLP é garantido, e PNG fica a verificar. Dimensões em potência de 2 são o mais seguro, então o construtor pode precisar fazer padding.
- **Resolução.** As texturas precisam ficar nítidas em 1080p, 1440p e 4K, e o HUD precisa escalar com a resolução e com a escala da interface.

## 4. O que foi decidido (layout e comportamento)

Referência visual navegável da versão aprovada:
`.superpowers/brainstorm/899-1792693301/content/hud-meshy-v11.html`, servida pelo companion visual. As medidas abaixo são em pixels da textura, e a tela de referência é 16:9.

### 4.1 Paleta e materiais
- **HUD:** pedra cinza-escura entalhada com rachaduras, ferro enegrecido e filetes finos de **bronze envelhecido**.
- **Textos e títulos:** dourado. Nomes no estilo serifado do jogo.
- **Raridade dos itens:** as cores oficiais do WoW. Ruim `#9d9d9d`, comum `#ffffff`, incomum `#1eff00`, raro `#0070dd`, épico `#a335ee`, lendário `#ff8000`.

### 4.2 HUD inferior (peça única)
- **Textura:** `art/processed/hud_bottom.png` (2692×381). É a metade esquerda gerada como peça única e espelhada para formar a direita. A emenda no centro é limpa.
- **Posição e tamanho:** ancorado embaixo, de ponta a ponta da tela. Ocupa cerca de 25% da altura numa tela 16:9.
- **Ordem, da esquerda para a direita:** orbe de vida, painel 3×3, barra de ações central, painel 3×3, orbe de recurso.
- **Furos dos orbes:** esquerdo em x 68–317, y 52–308; direito espelhado em x 2375–2624. O líquido é desenhado **atrás** da textura, visível pelo furo.
- **Slots dos painéis 3×3:** colunas da esquerda em x = 429, 488, 547 (largura 35); linhas em y = 143, 202, 262 (altura 41). O painel direito é espelhado (`x' = 2692 − x − 35`).
- **Barra de ações central: 2 fileiras × 18 colunas = 36 botões.**
  - Colunas da metade esquerda em x = 710, 782, 853, 925, 997, 1069, 1140, 1211, 1283 (largura 56). A metade direita é espelhada (`x' = 2692 − x − 56`).
  - Fileiras em y = 114 e 215 (altura 61).
- **Barra de XP:** **uma só**, no friso inferior, entre x ≈ 730 e 1962, y ≈ 341, altura ≈ 16. Preenchimento dourado e XP descansado em azul. Nada de outra barra de XP em lugar nenhum.

### 4.3 Orbes
- **Esquerdo:** vida, com líquido vermelho escuro.
- **Direito:** recurso principal. A **cor muda conforme o tipo**: mana azul, fúria vermelho-escuro, energia amarelo, foco laranja, poder rúnico ciano. Para os outros tipos, usar as cores padrão do jogo (`PowerBarColor`).
- **Líquido:** o nível acompanha a porcentagem. A superfície ondula de leve e tem textura de líquido girando devagar. A animação é sutil.
- **Vidro:** só sombra interna para dar volume. **Sem bolha de reflexo.**
- **Texto no centro:** porcentagem e, embaixo, valor atual / máximo abreviado (ex.: `28.4K / 39.5K`).
- **Troca de forma do druida:** o orbe direito troca de cor e de valor junto com a forma.

### 4.4 Painéis de menu (3×3)
- **Esquerdo:** Personagem, Grimório, Talentos, Profissões, Conquistas, Diário de Missões, Guilda/Comunidades, Coleções e Menu do jogo (ESC).
- **Direito:** Mochila, Bolsas 1–4, Bolsa de Reagentes, Social/Amigos, Procurar Grupo e PvP.
- **Ícones:** os ícones do próprio WoW, tingidos de dourado e bronze para combinar com o HUD.
- *A distribuição exata dos 18 botões foi escolha minha. O usuário aprovou a ideia de "menus do WoW nos painéis", mas não a lista. O construtor pode ajustar.*

### 4.5 Barras verticais opcionais (direita)
- **Quantidade:** até **2 barras de 12 botões**, presas à borda direita, abaixo do minimapa e acima do orbe de recurso.
- **Configuração:** cada uma liga e desliga **separadamente** nas configurações do addon. As duas começam desligadas.
- **Com 1 ligada:** `art/processed/vertical_bar.png` (156×1279). Slots em x = 38 (largura 78), y = 72, 168, 265, 361, 458, 554, 651, 748, 844, 941, 1037, 1133 (altura 75).
- **Com as 2 ligadas:** **uma peça só**, `art/processed/vertical_bar_double.png` (256×1279). Colunas em x = 38 e 138, sem moldura nem enfeite entre as colunas. Um único arco ornamentado no topo e outro na base. Requisito explícito do usuário.
- **Total possível:** 36 botões centrais + 24 verticais = 60.

### 4.6 Alvo, alvo do alvo e foco
- **Alvo, no topo esquerdo.** Textura `art/processed/target_frame.png` (1298×424).
  - Furo do retrato: x 104–400, y 72–374. Mostra o **retrato 2D parado**, como no WoW padrão (`SetPortraitTexture`). Decisão do usuário: **sem retratos 3D** no alvo, no foco, no alvo do alvo e no pet. O modelo 3D fica só no inventário.
  - Barra de vida: x 456–1240, y 202–257, com texto de porcentagem e valor.
  - Barra de recurso: x 461–1004, y 272–296.
  - Placa do nome: x ≈ 490–1070, y ≈ 105–185. Mostra o nome em dourado, o nível e a classificação (Elite, Raro etc.).
  - O anel do retrato ganha uma cor de classificação: roxo para elite, prata para raro, e assim por diante.
- **Debuffs no alvo:** fileira logo abaixo das barras do quadro do alvo, colada nele. Mostra os debuffs aplicados pelo jogador, com tempo restante.
- **Alvo do alvo:** retrato redondo pequeno com barra de vida, logo à direita do quadro do alvo.
- **Foco:** versão menor do quadro do alvo, logo abaixo dele.

### 4.7 Elementos centrais
- **Barra de conjuração:** centralizada, logo acima do HUD inferior. Tem ícone da magia, nome, tempo restante e preenchimento dourado. Também deve mostrar canalização e interrupção.
- **Recurso de classe:** gemas em losango entre a barra de conjuração e a barra de ações.
  - Exemplos: pontos de combo (ladino e druida felino), poder sagrado, fragmentos de alma, runas, chi, cargas arcanas, ou o que existir no Forever.
  - A quantidade e a cor variam por classe e especialização.
  - **Somem** para quem não tem recurso secundário.

### 4.8 Topo da tela
- **Buffs e debuffs do jogador:** **topo central**. Buffs numa fileira, debuffs com borda vermelha na fileira de baixo. Mostram tempo restante e número de acúmulos.
- **Minimapa:** **topo direito**, com **borda mínima**. Requisito explícito: "como se fosse uma borda".
  - **Borda:** usar `art/processed/minimap_thin.png`, que tem aro fino de pedra e bronze no padrão do HUD (ver seção 7, item 1). **Não usar** `art/processed/minimap.png`, rejeitado por ser grosso e enfeitado demais, nem uma borda chapada desenhada por código, rejeitada por não seguir o padrão.
  - **Plaquinha da zona:** pequena, com pontas arredondadas, presa no topo da borda.
  - **Botões:** 4 bolinhas pequenas presas à borda na parte de baixo, para relógio, correio, rastreamento e calendário.

### 4.9 Pet
- Retrato redondo pequeno com barras de vida e de recurso, logo acima do orbe de vida. Aparece só quando há pet.

### 4.10 Inventário unificado
O visual é de **pedra e bronze, igual ao HUD**. O usuário pediu que a moldura fosse gerada no Meshy. O vidro azul-noite do começo da conversa foi substituído.
- **Textura:** `art/processed/inventory.png` (690×1334). A moldura foi gerada no Meshy. As colunas de equipamento foram refeitas por edição de imagem com 8 slots cada, porque o Meshy não respeitava a contagem.
- **Medidas da textura:**
  - Título: x 187–502, y 31–70.
  - Área do modelo 3D: x 168–518, y 95–470.
  - Slots de equipamento, com 54 de lado e 8 por coluna: centros das colunas em x = 96.5 e 591.5; topo do slot `i` em y ≈ 110 + i·70.75.
  - **Armas, agora quadradas** como os ícones do WoW (pedido do usuário): 3 slots de 100×100 em x = 182, 294 e 406, y = 518. Área do ícone com recuo de 9 px.
  - Abas: x = 80, 187, 296, 405 e 515 (largura 93), y 702–737.
  - Grade de bolsas: colunas em x = 44, 116, 189, 261, 333, 405, 478 e 550 (largura 59); linhas em y = 761, 841, 918, 995, 1072 e 1149 (altura 59).
  - Rodapé: bolsas em x = 42, 119, 196, 273 e 350 (64×66), y = 1234. Placa do ouro em x 445–647, y 1247–1285.
- **Mockup:** `inventario-pedra.html`, no diretório do companion visual.
- **Modelo 3D do jogador:** a área do modelo usa um frame `PlayerModel`/`DressUpModel` com `SetUnit("player")`, igual à ficha padrão do WoW.
  - Mostra o personagem real, com equipamento e transmogrificação, e atualiza quando o equipamento muda.
  - **Fundo transparente**, para o boneco ficar sobre a pedra da moldura.
  - Gira arrastando com o mouse e tem zoom pela rodinha.
  - Câmera de corpo inteiro e luz quente, para combinar com o bronze.
- **Janela única:** substitui a ficha do personagem e as bolsas.
- **Em cima:** equipamento, com o modelo 3D do personagem no centro. São **8 slots de cada lado**: cabeça, pescoço, ombros, costas, peito, camisa, tabardo e pulsos à esquerda; mãos, cintura, pernas, pés, 2 anéis e 2 berloques à direita. Embaixo ficam **3 slots de arma**: mão principal, mão secundária e à distância/relíquia. Se o Forever não tiver o slot à distância, o terceiro fica escondido.
- **Embaixo:** todas as bolsas viram **uma grade única de 8 colunas**, sem separação entre bolsas.
- **Tamanho fixo:** a janela não muda de tamanho. Quanto mais espaços de bolsa, mais linhas, e a grade **rola por dentro**. Trocar uma bolsa por uma maior nunca deixa slot torto.
- **Abas de filtro:** Tudo, Equipamento, Consumíveis, Materiais e Reagentes. A bolsa de reagentes fica na aba Reagentes.
- **Rodapé:** slots das bolsas equipadas e o ouro.
- **Itens:** borda fina na cor de raridade com brilho interno suave, e números de pilha legíveis. Os slots são maiores que os do WoW padrão.
- **Grade:** a textura mostra 8×6 slots. Quando houver mais espaços de bolsa, a grade rola dentro dessa área, e os slots extras são criados por código usando a mesma aparência.

## 5. Assets e ferramentas que já existem

- **`art/meshy/`:** as imagens originais geradas no Meshy, com fundo magenta.
- **`art/processed/`:** as mesmas peças com o fundo removido e recortadas.
  - **Peças em uso:** `hud_bottom.png`, `target_frame.png`, `vertical_bar.png`, `vertical_bar_double.png`.
  - **Peças de apoio:** `button_slot.png`, uma borda de slot avulsa, útil para slots criados por código.
  - **Peças descartadas ou só de referência:** `orb_frame.png`, `side_panel.png`, `action_bar.png`, `base_plate.png`, `bridge.png`, `xp_strip.png`, `minimap.png` e `hud_left_*`.
- **`tools/meshy_gen.py`:** gera peças pela API do Meshy (image-to-image, modelo `nano-banana-2`, usando a referência como guia de estilo). A chave fica em `.meshy-key.txt`, que **não pode ser publicado nem versionado**. Cada imagem custa cerca de 6 créditos.
- **`tools/process_art.py`:** remove o fundo magenta, limpa o contorno rosado e recorta.
- **Contorno rosado:** algumas bordas ainda têm um leve resto de magenta. Precisa ser limpo antes de virar textura final.

## 6. O que fica a cargo do construtor

- **Nome do addon** e estrutura de arquivos (`.toc`, Lua, XML). O número `## Interface` deve ser pego no jogo com `/dump select(4, GetBuildInfo())`.
- **Mapeamento dos 36 botões centrais e dos 24 verticais** para as barras e slots de ação do WoW, mantendo os atalhos padrão do jogo (1–0, -, = etc.).
- **Botões de ação:** cooldown, alcance, falta de recurso, cargas, macros e a contagem de itens. Devem seguir o comportamento padrão do WoW.
- **Como esconder os frames da Blizzard** que o HUD substitui (barras de ação, PlayerFrame, TargetFrame, FocusFrame, minimapa padrão, buffs, castbar, barra de XP, micro menu e barra de bolsas), sem quebrar o Edit Mode nem causar taint.
- **Escala:** opção de escala global do HUD, no mínimo. Integração com o Edit Mode para mover peças é desejável, mas não obrigatória nesta fase.
- **Página de configurações** do addon no painel de Configurações do jogo, com os interruptores das barras verticais e a escala. A versão "bonita" das configurações vem com o kit de janelas na fase 2.
- **Conversão e empacotamento** das texturas para o formato aceito pelo cliente.

## 7. Decisões tomadas depois da revisão (escolhas minhas, o usuário pode mudar)

1. **Arte das peças que faltavam (revisado: o usuário pediu Meshy, com detalhes minimalistas no padrão do HUD).** Todas as texturas ficam em `art/processed/`.

   | Peça | Arquivo e tamanho | Medidas |
   |---|---|---|
   | **Alvo do alvo e pet** | `unit_small.png` (1274×494) | Furo do retrato: x 67–418, y 66–426. Nome: x 495–1230, y 108–174. Vida: x 502–1226, y 208–280. Recurso: x 507–1215, y 320–360. |
   | **Foco** | `focus_frame.png` (1252×486) | Furo: x 62–420, y 60–424. Nome: x 492–1212, y 116–188. Vida: x 500–1212, y 210–278. Recurso: x 500–1200, y 296–334. |
   | **Barra de conjuração** | `castbar.png` (1320×176) | Encaixe do ícone: x 56–146, y 40–128. Ranhura da barra: x 196–1254, y 56–118. |
   | **Gemas do recurso de classe** | `gem_socket.png` (vazia) e `gem_lit.png` (acesa) | Uma imagem por gema. |
   | **Minimapa** | `minimap_thin.png` (1008×1012) | Furo do mapa: x 86–923, y 88–924. Plaquinha da zona: x 350–660, y 10–76. 4 encaixes, com centros em (180,824), (348,932), (660,932) e (826,824) e diâmetro de 56. |

   - Esse minimapa substitui a borda desenhada por código. Ele segue o padrão de pedra e bronze e continua minimalista.
   - **Continuam desenhados por código:** o líquido e a sombra dos orbes, e o preenchimento das barras.
   - Toda arte nova do Meshy é **mostrada ao usuário antes de entrar no addon**.
   - Mockup de referência: `visao-geral-v2.html`.
2. **Testes no jogo.** Quem tem o cliente do WoW Forever é o usuário. Cada "conferir no jogo" vira um **ponto de verificação**: o construtor entrega um comando ou um build, o usuário roda e devolve o resultado. O plano deve agrupar essas verificações cedo, logo na primeira entrega: número da Interface, nomes dos frames, valores secretos e suporte a PNG.
3. **Barras de ação especiais**
   - **Veículo, override, possessão e forma:** a **fileira de cima da barra central** troca para as ações especiais, como no WoW padrão, usando o state driver seguro. O botão de sair do veículo aparece ao lado da barra de conjuração.
   - **Barra de postura/forma:** uma fileira pequena de botões, centralizada logo acima da barra de ações. Aparece só para quem tem posturas ou formas.
   - **Barra do pet:** uma fileira pequena ao lado da barra de postura. Aparece só com pet.
   - **Botão de ação extra e habilidade de zona:** os da Blizzard continuam, reposicionados acima da barra de conjuração e com uma borda simples no estilo do HUD.
4. **Ficha do personagem.** O botão Personagem e a tecla C abrem a janela unificada. Ela tem uma **coluna de atributos recolhível** ao lado do equipamento. Reputação, moedas, títulos e conjuntos de equipamento continuam nas janelas da Blizzard, acessadas por botões pequenos na janela unificada. Essas janelas ganham pele nova na fase 2.
5. **Telas que não são 16:9 (revisado a pedido do usuário: "encaixar certinho com o fim da tela e ser responsivo").** O HUD inferior **sempre encosta na base e nas duas laterais da tela.** A textura da metade esquerda é fatiada em três partes:
   - **Ponta:** x 0–656. Orbe e painel 3×3, presa ao canto.
   - **Faixa de pedra:** x 656–662. Estica horizontalmente para preencher o espaço.
   - **Meia barra:** x 662–1346. Presa ao centro da tela.

   A metade direita é o espelho. A altura do HUD é `min(25% da altura da tela, largura / 2680 × 381)`. Em telas mais estreitas que o HUD, ele encolhe para caber e o espaço do meio fica com largura zero.
   - **Preenchimento do espaço (revisado depois que o usuário achou a pedra esticada "bugada" no ultrawide):** o espaço não estica mais. Ele é preenchido **repetindo** `art/processed/hud_connector.png` (333×381). É uma parede de pedra gerada no Meshy, com filete de bronze no topo e friso embaixo, e repete na horizontal sem emenda.
   - **O último trecho é cortado** por texcoord para fechar a largura exata.
   - **O lado direito usa o trecho espelhado.**
6. **Frames da Blizzard que continuam na tela.** Na fase 1, o addon define posições padrão que não encostam no HUD:
   - **Chat:** acima do HUD, na esquerda.
   - **Rastreador de missões:** na direita, entre o minimapa e as barras verticais.
   - **Alertas:** no centro-alto.
   - **Cooldown Manager e medidor de dano:** ficam com o Edit Mode, e o usuário posiciona. O addon só garante que as posições iniciais não se sobreponham ao HUD.

## 8. Questões em aberto

Nenhuma. O estilo do inventário foi resolvido: pedra e bronze, gerado no Meshy.
