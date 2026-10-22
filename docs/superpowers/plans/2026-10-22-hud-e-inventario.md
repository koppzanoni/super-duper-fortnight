# ObsidianUI: HUD de combate e inventário (fase 1) — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir o addon `ObsidianUI` para WoW Forever. Ele substitui o HUD de combate e o inventário padrão pelo visual de pedra e bronze no estilo PoE 2 que foi aprovado no spec.

**Architecture:**
- **Módulos puros em Lua**, sem chamadas de API do WoW, testados fora do jogo com pytest + lupa: layout, tabelas de dados, filtros e modelo da grade.
- **Módulos de frame**, um por elemento do HUD. Eles consomem os módulos puros.
- **Elementos com lógica de combate pesada** (conjuração, barras de postura e pet, botão extra) reaproveitam os frames da Blizzard, reposicionados e com pele nova. Isso convive com os valores secretos da API 12.x.
- **Texturas:** um script Python gera os `.tga` em potência de 2 e um `Media/manifest.lua` com as coordenadas de textura.
- **O que só existe dentro do jogo** é validado por **pontos de verificação** que o usuário executa no WoW Forever.

**Tech Stack:** Lua 5.1 (WoW, API Mainline 12.x), LibStub + CallbackHandler-1.0 + LibActionButton-1.0 (embutidas), Python 3.12 (Pillow, numpy, pytest, lupa).

**Spec:** `docs/superpowers/specs/2026-10-22-hud-e-inventario-design.md`. Leia o spec junto com este plano: as medidas em pixels das texturas estão nas seções 4.2, 4.5, 4.6 e 4.10.

## Global Constraints

- **Cliente alvo:** só o WoW Forever (API Mainline 12.x). Não dar suporte a Classic nem Retail.
- **Número da Interface do `.toc`:** vem do ponto de verificação da Tarefa 1 (`/dump select(4, GetBuildInfo())`). Até lá, usar `120105`.
- **Valores secretos:** nunca fazer conta nem comparação em Lua com vida, recurso, tempos de aura ou de conjuração. Esses valores só podem ir para widgets nativos (`StatusBar:SetValue`, `FontString:SetText`, `AbbreviateNumbers`, `Cooldown`). Antes de ramificar, testar com `issecretvalue(v)` quando a função existir.
- **Combate:** nenhum frame protegido pode ser criado, mostrado, escondido, reparentado ou movido em combate. Mudanças pedidas em combate entram numa fila e rodam em `PLAYER_REGEN_ENABLED`.
- **Cores de raridade:** ruim `#9d9d9d`, comum `#ffffff`, incomum `#1eff00`, raro `#0070dd`, épico `#a335ee`, lendário `#ff8000`.
- **Cores dos orbes:**

  | Recurso | Hex | RGB (0–1) |
  |---|---|---|
  | Vida | `#c8291f` | 0.78, 0.16, 0.12 |
  | Mana | `#2f63d6` | 0.18, 0.39, 0.84 |
  | Fúria | `#9e140d` | 0.62, 0.08, 0.05 |
  | Energia | `#f2cc1a` | 0.95, 0.80, 0.10 |
  | Foco | `#f2801f` | 0.95, 0.50, 0.12 |
  | Poder rúnico | `#00c7eb` | 0.00, 0.78, 0.92 |
  | Outros | `PowerBarColor[token]` | |

- **Texto e títulos:** dourado `#e8c46a`. Bronze dos filetes desenhados por código: `#8a6d3b` e `#c9a24a`. Ferro escuro: `#16171b`.
- **Anti-objetivos do spec:** enfeites grandes, peças desencaixadas, barra de XP duplicada, moldura dupla entre as barras verticais e reflexos nos orbes. **Nada desenhado por código pode reintroduzir nenhum deles.**
- **Segredo:** `.meshy-key.txt` nunca vai para o git.

## Review Focus

1. **Mudar configurações ou abrir as bolsas em combate.** Esperado: a mudança espera o fim do combate e não aparece o erro "ação bloqueada". Teste: `test_combat_queue_defers_until_regen` (Tarefa 3). Também entra na verificação de combate das Tarefas 7 e 17.
2. **Veículo, override, possessão e formas de druida.** Esperado: a fileira de cima da barra central troca de página, e o orbe direito troca de cor e de valor. Teste: `test_paging_driver_string` (Tarefa 3) e o ponto de verificação da Tarefa 6.
3. **Resolução que não é 16:9 e troca de escala da UI.** Esperado: o HUD fica centralizado e não estica, e se refaz em `UI_SCALE_CHANGED` e `DISPLAY_SIZE_CHANGED`. Teste: `test_hud_size_*` (Tarefa 3).
4. **Quantidade de espaços nas bolsas muda,** porque uma bolsa é trocada ou porque falta a bolsa de reagentes. Esperado: as linhas da grade se recalculam e nunca acessam um slot inexistente. Teste: `test_grid_rows_*` e `test_grid_handles_missing_bag` (Tarefa 15).
5. **Valores secretos em combate.** Esperado: nenhum erro do tipo "attempt to compare/perform arithmetic on a secret value". Teste: `test_no_arithmetic_on_unit_values` (Tarefa 1). É uma verificação estática que procura comparações com `UnitHealth`, `UnitPower` e afins. Também entra no ponto de verificação de combate da Tarefa 5.

---

## Estrutura de arquivos

```
ObsidianUI/                      # pasta do addon (junction para Interface/AddOns/ObsidianUI)
  ObsidianUI.toc
  Libs/                          # LibStub, CallbackHandler-1.0, LibActionButton-1.0 (cópias oficiais)
  Media/*.tga, Media/manifest.lua   # gerados pela Tarefa 2
  Core/Init.lua                  # namespace, eventos, SavedVariables, fila de combate
  Core/Layout.lua                # PURO: conversão px-da-textura → offsets do frame, espelhamento, tamanho do HUD
  Core/Data.lua                  # PURO: coordenadas do spec, cores, recursos de classe, menus, slots, mapeamento de ações
  Core/Resolve.lua               # PURO: primeiro nome global existente numa lista de candidatos
  Core/Diag.lua                  # /obui diag
  Core/HideBlizzard.lua
  Core/Media.lua                 # helper que aplica textura + texcoords do manifest
  HUD/Bottom.lua  HUD/XPBar.lua  HUD/Orbs.lua  HUD/ActionBars.lua  HUD/VerticalBars.lua
  HUD/MenuPanels.lua  HUD/SpecialBars.lua  HUD/UnitFrames.lua  HUD/CastBar.lua
  HUD/ClassResource.lua  HUD/Auras.lua  HUD/Minimap.lua  HUD/DefaultPositions.lua
  Inventory/Filters.lua          # PURO
  Inventory/GridModel.lua        # PURO
  Inventory/Window.lua  Inventory/BagGrid.lua
  Settings/Settings.lua
tools/export_textures.py
tests/conftest.py  tests/wowstub.lua  tests/test_*.py
```

---

### Tarefa 1: Repositório, harness de testes, esqueleto do addon e diagnóstico

**Files:**
- Create: `.gitignore`, `requirements-dev.txt`, `ObsidianUI/ObsidianUI.toc`, `ObsidianUI/Core/Init.lua`, `ObsidianUI/Core/Diag.lua`, `ObsidianUI/Core/Resolve.lua`, `tests/conftest.py`, `tests/wowstub.lua`, `tests/test_load.py`, `tests/test_static.py`, `tests/test_resolve.py`

**Interfaces:**
- Produces:
  - Namespace `ns` (segundo vararg de cada arquivo).
  - `ns.On(event, fn)` — barramento de eventos.
  - `ns.RunOutOfCombat(fn)` — executa já, ou coloca na fila até `PLAYER_REGEN_ENABLED`.
  - `ns.db` — SavedVariables `ObsidianUIDB`, com defaults `{ vbar1=false, vbar2=false, scale=1.0 }`.
  - `ns.Resolve.First(names, env)` — retorna `obj, name` ou `nil`.
  - Fixture pytest `lua` (runtime lupa no modo LuaJIT, com semântica de Lua 5.1).
  - Helper `load_addon_file(rt, path, ns)`.

- [ ] **Passo 1: `git init`, `.gitignore` e dependências.**
  - O `.gitignore` deve conter: `.meshy-key.txt`, `.superpowers/`, `__pycache__/`, `art/meshy/`.
  - O `requirements-dev.txt` deve conter: `pillow`, `numpy`, `pytest`, `lupa`.
  - Rodar `pip install -r requirements-dev.txt`. Resultado esperado: instala sem erro.
  - Criar `ObsidianUI/Media/test.png` e `ObsidianUI/Media/test.tga` (64×64, cor sólida `#c9a24a`) com um one-liner do Pillow. Eles são usados pelo diagnóstico, e a Tarefa 2 depois os recria.
- [ ] **Passo 2: Escrever os testes que falham.**
  - `tests/test_resolve.py::test_first_existing_name`: `First({"A","B"}, {B=1})` retorna `1, "B"`.
  - `test_none_exists`: retorna `nil`.
  - `tests/test_load.py::test_every_toc_file_loads`: lê o `.toc`, pula `Libs/` e as linhas `##`, e carrega cada `.lua` em lupa com o `tests/wowstub.lua`. O stub é uma tabela com metatable que devolve funções e frames falsos para qualquer global. Nenhum arquivo pode levantar erro.
  - `tests/test_static.py::test_no_arithmetic_on_unit_values`: um regex sobre `ObsidianUI/**/*.lua` não pode encontrar `\b(UnitHealth|UnitHealthMax|UnitPower|UnitPowerMax)\([^)]*\)\s*([<>+\-*/]|==|~=)`. A fronteira de palavra e o `\(` evitam acusar `UnitPowerType`. Inclua também um caso negativo no próprio teste: `UnitPowerType("player") == 0` não pode disparar.
- [ ] **Passo 3: Rodar `pytest -q`.** Resultado esperado: FAIL (módulos ausentes).
- [ ] **Passo 4: Implementar.**
  - `.toc`: com `## Interface: 120105`, `## SavedVariables: ObsidianUIDB` e a ordem de carga da estrutura acima.
  - `Init.lua`: implementa `ns.On`, `ns.RunOutOfCombat` (usa `InCombatLockdown()`) e `ns.db`.
  - `Resolve.lua`: `First` percorre os nomes e devolve o primeiro valor não nulo de `env or _G`.
  - `Diag.lua`: o comando `/obui diag` imprime:
    - (a) `GetBuildInfo()`;
    - (b) para cada lista em `ns.Data.FRAME_CANDIDATES` (Tarefa 3; antes disso, usar uma lista local), o nome que existe;
    - (c) `issecretvalue ~= nil` e `issecretvalue(UnitHealth("player"))`, agora e no próximo `PLAYER_REGEN_DISABLED`;
    - (d) a mesma checagem para `UnitPower("player", Enum.PowerType.ComboPoints)`;
    - (e) um frame de teste com `Media/test.png` e `Media/test.tga` lado a lado, para o usuário dizer se os dois aparecem.
- [ ] **Passo 5: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 6: Commit.** Mensagem: `feat: addon skeleton, test harness and /obui diag`.
- [ ] **Passo 7: PONTO DE VERIFICAÇÃO (usuário).**
  - Criar a junction: `mklink /J "<WoW>\_forever_\Interface\AddOns\ObsidianUI" "C:\Users\Arthur\Desktop\uid\ObsidianUI"`. O caminho exato do WoW vem do usuário.
  - Entrar no jogo e rodar `/obui diag` fora de combate e depois em combate com um boneco de treino.
  - Colar a saída e dizer se as imagens PNG e TGA aparecem.
  - Com isso, atualizar o número da Interface e os candidatos de frames, e registrar os achados no topo deste plano antes da Tarefa 4.

### Tarefa 2: Pipeline de texturas

**Files:**
- Create: `tools/export_textures.py`, `tests/test_export.py`
- Generates: `ObsidianUI/Media/*.tga`, `ObsidianUI/Media/manifest.lua`, `ObsidianUI/Media/test.png`, `ObsidianUI/Media/test.tga`

**Interfaces:**
- Produces: `Media/manifest.lua`, que retorna uma tabela `{ [name] = { file="Interface\\AddOns\\ObsidianUI\\Media\\<name>", w=, h=, potW=, potH= } }`.
- Nomes:
  - **Da arte:** `hud_cap` (x 0–656), `hud_connector` (`art/processed/hud_connector.png`, 333×381, trecho repetível), `hud_bar` (x 662–1346), `target_frame`, `unit_small`, `focus_frame`, `castbar`, `gem_on` (`gem_lit.png`), `gem_off` (`gem_socket.png`), `minimap_ring` (`minimap_thin.png`), `vbar1`, `vbar2`, `inventory`, `slot`.
  - **Procedurais:** `mask_circle`, `liquid` (gradiente em tons de cinza, tingido por `SetVertexColor`), `swirl` (ruído tileável), `wave`, `bar_fill`, `aura_border`.

- [ ] **Passo 1: Escrever os testes que falham** (`tests/test_export.py`).
  - `test_pot_padding`: um PNG de 1346×381 vira TGA de 2048×512 e o manifest registra `w=1346, h=381`.
  - `test_hud_slices`: as larguras de `hud_cap` e `hud_bar` são 656 e 684, e `hud_connector` tem 333×381.
  - `test_defringe_removes_pink`: num pixel de borda com alfa entre 0 e 255, a condição `min(R,B) - G <= 10` é verdadeira.
  - `test_mask_circle_alpha`: alfa 255 no centro e 0 nos cantos.
  - `test_manifest_is_valid_lua`: o manifest carrega no lupa e `hud_left.potW == 2048`.
- [ ] **Passo 2: Rodar `pytest tests/test_export.py -q`.** Resultado esperado: FAIL.
- [ ] **Passo 3: Implementar `export_textures.py` (roda com `python tools/export_textures.py`).**
  - **Fontes:**
    - `hud_cap` e `hud_bar` saem de `art/processed/hud_bottom.png` cortado em x 0–656 e 662–1346. `hud_connector` é copiado sem cortes.
    - `vbar1` = `vertical_bar.png`; `vbar2` = `vertical_bar_double.png`; `slot` = `button_slot.png` reduzido para 128×128.
  - **Defringe:** nos pixels com `0 < alfa < 255`, `R -= max(0, min(R,B) - G)` e o mesmo para B.
  - **Padding:** canto superior esquerdo, completando com transparente até a próxima potência de 2, com máximo de 2048.
  - **Procedurais:** `ring_thin` é um anel de 256 px com 3 px de `#16171b` entre filetes de 1 px de `#c9a24a` e `#8a6d3b`.
- [ ] **Passo 4: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 5: Commit.** Mensagem: `feat: texture export pipeline and manifest`.

### Tarefa 3: Módulos puros de layout e dados

**Files:**
- Create: `ObsidianUI/Core/Layout.lua`, `ObsidianUI/Core/Data.lua`, `ObsidianUI/Core/Media.lua`, `tests/test_layout.py`, `tests/test_data.py`, `tests/test_init.py`

**Interfaces:**
- **Consumes:** manifest da Tarefa 2; `ns.RunOutOfCombat` da Tarefa 1.
- **Produces — Layout:**
  - `ns.Layout.Rect(texW, texH, frameW, frameH, x, y, w, h)` retorna `left, top, width, height`. O `top` é negativo, pronto para `SetPoint("TOPLEFT")`.
  - `ns.Layout.MirrorX(texW, x, w)` retorna `texW - x - w`.
  - `ns.Layout.HudSize(screenW, screenH, userScale)` retorna `h, u, stretch`, usando as regras:
    - `h = min(0.25*screenH, screenW*381/2680) * userScale`;
    - `u = h/381`;
    - `stretch = max(0, screenW/2 - 684*u - 656*u)`, que é a largura de cada espaço preenchido pelo conector.
  - `ns.Layout.MapX(x, screenW, u)` converte o x virtual da metade esquerda (0–1346): retorna `x*u` quando `x <= 656` e `screenW/2 - (1346-x)*u` nos outros casos. Para o lado direito, espelhar.
- **Produces — Media:** `ns.Media.Apply(texture, name, mirror)` define a textura e `SetTexCoord(0, w/potW, 0, h/potH)`, ou o inverso em x quando `mirror` é verdadeiro.
- **Produces — Data:** `ns.Data` com:
  - `HUD`: dimensões 2692×381 e as coordenadas dos furos dos orbes, dos slots dos painéis 3×3, das 9 colunas por metade e 2 fileiras da barra, e da ranhura de XP, todas do spec 4.2.
  - `VBAR1`, `VBAR2` (spec 4.5); `TARGET` (spec 4.6); `INV` (spec 4.10).
  - `ORB_COLORS` (Global Constraints) e `PowerColor(token)`.
  - `CLASS_RESOURCE`, `ClassResourceFor(classToken, specIndex, unitPowerType)`, que retorna `{ powerType=, color={r,g,b} }` ou `nil`.
  - `MENU_LEFT`, `MENU_RIGHT`: listas de 9 `{ id=, label=, candidates={nomes de micro botão} }`.
  - `EQUIP_LEFT`, `EQUIP_RIGHT`, `WEAPONS` (spec 4.10).
  - `ACTION_LAYOUT`: para cada uma das 36 posições `{row, col}`, retorna `{ bar=, actionID=, binding= }`.
  - `PagingDriver()`: retorna a string do state driver.
  - `FRAME_CANDIDATES`: listas de nomes alternativos para o frame de conjuração, a barra de postura, a barra de pet, o botão extra, a habilidade de zona, o botão de sair do veículo, os micro botões, os ícones do minimapa, o rastreador de missões e as bolsas padrão.

- [ ] **Passo 1: Escrever os testes que falham.**
  - `test_rect_scales`: `Rect(2692,381, 1346,190.5, 710,114,56,61)` retorna `355, -57, 28, 30.5`.
  - `test_mirror`: `MirrorX(2692, 710, 56)` retorna `1926`.
  - `test_hud_size_16_9`: `HudSize(1920,1080,1)` retorna `h=270` e `stretch≈10.4`.
  - `test_hud_size_21_9`: `HudSize(2560,1080,1)` retorna `h=270` e `stretch≈330.4`.
  - `test_hud_size_16_10`: `HudSize(1920,1200,1)` retorna `h≈272.96` e `stretch≈0`.
  - `test_mapx`: `MapX(656,1920,0.70866)` retorna `≈464.9`; `MapX(1346,1920,u)` retorna `960`.
  - `test_action_layout_36_unique`: 36 entradas com `actionID` sem repetição.
    - Fileira 1, colunas 1–12: ações 1–12, `ACTIONBUTTON1..12`.
    - Colunas 13–18 das duas fileiras: ações 61–72, `MULTIACTIONBAR1BUTTON1..12`.
    - Fileira 2, colunas 1–12: ações 49–60, `MULTIACTIONBAR2BUTTON1..12`.
  - `test_vbar_actions`: vbar1 usa 25–36 (`MULTIACTIONBAR3`) e vbar2 usa 37–48 (`MULTIACTIONBAR4`).
  - `test_paging_driver_string`: a string contém, nesta ordem: `[vehicleui] 12`, `[overridebar] 14`, `[possessbar] 12`, `[shapeshift] 13`, `[bonusbar:5] 11`, `[bonusbar:1] 7`, `[bonusbar:2] 8`, `[bonusbar:3] 9`, `[bonusbar:4] 10` e termina em `1`.
  - `test_class_resource`:
    - `ClassResourceFor("ROGUE")` retorna ComboPoints.
    - `ClassResourceFor("DRUID", nil, Enum.PowerType.Energy)` retorna ComboPoints.
    - `ClassResourceFor("DRUID", nil, Enum.PowerType.Mana)` retorna `nil`.
    - `ClassResourceFor("WARRIOR")` retorna `nil`.
    - `ClassResourceFor("MAGE", 1)` retorna ArcaneCharges.
    - `ClassResourceFor("MAGE", 2)` retorna `nil`.
    - PALADIN usa HolyPower, WARLOCK usa SoulShards, DEATHKNIGHT usa Runes e MONK com `specIndex` 3 usa Chi.
  - `test_power_colors`: `PowerColor("MANA")` retorna `0.18, 0.39, 0.84`; um token desconhecido cai em `PowerBarColor`.
  - `test_menus`: cada menu tem 9 entradas, os ids são únicos e a primeira entrada de `MENU_LEFT` tem `id == "character"`.
  - `test_equip_slots`: 8 + 8 + 3 slots, com `EQUIP_LEFT[1] == "HeadSlot"` e `WEAPONS[3] == "RangedSlot"`.
  - `tests/test_init.py::test_combat_queue_defers_until_regen`: com `InCombatLockdown` devolvendo true, a função não roda; depois de disparar `PLAYER_REGEN_ENABLED`, ela roda uma vez.
- [ ] **Passo 2: Rodar `pytest -q`.** Resultado esperado: FAIL.
- [ ] **Passo 3: Implementar os três módulos.** Os valores vêm do spec e dos testes, e não há outra lógica.
- [ ] **Passo 4: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 5: Commit.** Mensagem: `feat: pure layout/data modules`.

### Tarefa 4: HUD inferior, XP e esconder a Blizzard

**Files:**
- Create: `ObsidianUI/Core/HideBlizzard.lua`, `ObsidianUI/HUD/Bottom.lua`, `ObsidianUI/HUD/XPBar.lua`
- Modify: `.toc`

**Interfaces:**
- **Consumes:** `Layout.HudSize`, `Layout.Rect`, `Media.Apply`, `Data.HUD`, `Data.FRAME_CANDIDATES`.
- **Produces:**
  - `ns.HUD.frame`: o frame raiz, ancorado em `BOTTOM` do UIParent, centralizado.
  - `ns.HUD.Place(region, x, y, w, h)`: posiciona uma região usando as coordenadas virtuais de 2692×381.
  - `ns.HUD.onResize`: lista de callbacks.

- [ ] **Passo 1: `Bottom.lua`.**
  - Texturas:
    - `hud_cap` em `BOTTOMLEFT`;
    - o espaço de largura `stretch` é preenchido com `ceil(stretch / (333*u))` texturas `hud_connector` lado a lado, cada uma com 333u×381u; a última é cortada com `SetTexCoord` para fechar a largura exata;
    - `hud_bar` com a borda direita no centro;
    - o espelho de tudo isso na direita (`mirror=true`).
  - Os conectores ficam **por baixo** das texturas da ponta e da barra. O HUD **sempre encosta na base e nas duas laterais**.
  - Teste a mais em `tests/test_layout.py`, com a função pura `ns.Layout.ConnectorPieces(stretch, tileW)` → lista de larguras. `test_connector_pieces`: `ConnectorPieces(700, 333)` retorna `{333, 333, 34}`; `ConnectorPieces(0, 333)` retorna `{}`.
  - O tamanho vem de `HudSize(UIParent:GetSize(), ns.db.scale)`. `HUD.Place` converte o x com `Layout.MapX`.
  - Refaz o layout em `UI_SCALE_CHANGED` e `DISPLAY_SIZE_CHANGED`, e chama os callbacks de `onResize`.
- [ ] **Passo 2: `XPBar.lua`.**
  - Um StatusBar na ranhura do spec 4.2, com preenchimento `#c9a24a` e XP descansado em `#0070dd` a 60%.
  - Eventos: `PLAYER_XP_UPDATE`, `UPDATE_EXHAUSTION`, `PLAYER_LEVEL_UP`.
  - No nível máximo, a barra fica vazia.
- [ ] **Passo 3: `HideBlizzard.lua`.**
  - Esconde, dentro de `RunOutOfCombat`, com `UnregisterAllEvents` + `Hide` + `hooksecurefunc(frame,"Show",frame.Hide)` quando o frame não for protegido, ou `SetParent(hiddenFrame)` quando for:
    - MainMenuBar/MainActionBar, MultiBarBottomLeft/Right, MultiBarRight/Left
    - PlayerFrame, TargetFrame, FocusFrame
    - MicroMenuContainer, BagsBar, StatusTrackingBarManager
    - BuffFrame, DebuffFrame
  - Os nomes vêm de `Resolve.First(Data.FRAME_CANDIDATES.x)`.
  - **Não esconder** o frame de conjuração, a barra de postura, a barra de pet nem o botão extra. Eles são tratados nas Tarefas 9 e 11.
- [ ] **Passo 4: Rodar `pytest -q`.** Resultado esperado: PASS (o `test_load` cobre os arquivos novos).
- [ ] **Passo 5: Commit.** Mensagem: `feat: unified bottom HUD, XP bar, hide default bars`.
- [ ] **Passo 6: PONTO DE VERIFICAÇÃO (usuário).** Depois de `/reload`:
  - O rodapé aparece inteiro, sem emenda visível no centro.
  - As barras padrão sumiram.
  - O XP enche ao ganhar experiência.
  - Em 16:9 o HUD vai de ponta a ponta. Testar também mudar a escala da UI.

### Tarefa 5: Orbes

**Files:**
- Create: `ObsidianUI/HUD/Orbs.lua`
- Modify: `.toc`

**Interfaces:**
- **Consumes:** `ns.HUD.Place`, `Data.HUD.orbLeft`/`orbRight`, `Data.PowerColor`, `Media.Apply`.
- **Produces:** `ns.Orbs.health` e `ns.Orbs.power`, cada um com o campo `.bar` (StatusBar).

- [ ] **Passo 1: Montar cada orbe, por baixo da textura do HUD (frame level menor), no furo do spec 4.2.**
  - Fundo `#050608`.
  - StatusBar **vertical** com a textura `liquid` tingida pela cor do orbe.
  - `MaskTexture` `mask_circle` aplicada ao preenchimento, ao `swirl` e à `wave`.
  - `wave` ancorada com `BOTTOM` no `TOP` de `bar:GetStatusBarTexture()`. Isso usa só âncoras, sem conta com valor secreto.
  - `swirl` com `AnimationGroup` de translação lenta, em loop, a 45% de opacidade.
  - Sombra interna: textura `mask_circle` invertida, escura nas bordas.
  - **Não criar textura de reflexo.**
- [ ] **Passo 2: Valores.**
  - `SetMinMaxValues(0, UnitHealthMax)` e `SetValue(UnitHealth)`.
  - Texto: porcentagem com `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` quando a função existir; senão, só o valor abreviado. Na linha de baixo, `AbbreviateNumbers(atual) .. " / " .. AbbreviateNumbers(max)` passados para `SetText`.
  - O orbe direito usa `UnitPower` e `UnitPowerMax` com o tipo de `UnitPowerType("player")`. A cor é reaplicada em `UNIT_DISPLAYPOWER`, ou seja, quando a forma do druida muda.
- [ ] **Passo 3: Rodar `pytest -q`.** Resultado esperado: PASS (inclui `test_no_arithmetic_on_unit_values`).
- [ ] **Passo 4: Commit.** Mensagem: `feat: health and power orbs`.
- [ ] **Passo 5: PONTO DE VERIFICAÇÃO (usuário).**
  - Tomar dano de um boneco: o líquido desce e não aparece erro Lua.
  - Druida trocando de forma: o orbe muda de cor.
  - Guerreiro: fúria em vermelho-escuro.

### Tarefa 6: Barra de ações central (36 botões)

**Files:**
- Create: `ObsidianUI/Libs/*` (LibStub, CallbackHandler-1.0, LibActionButton-1.0), `ObsidianUI/HUD/ActionBars.lua`
- Modify: `.toc`

**Interfaces:**
- **Consumes:** `Data.ACTION_LAYOUT`, `Data.PagingDriver()`, `ns.HUD.Place`.
- **Produces:** `ns.ActionBars.CreateButton(parent, id, actionID, binding)`, que devolve um botão LAB com a pele do ObsidianUI. A Tarefa 7 reaproveita essa função.

- [ ] **Passo 1: Criar os botões.**
  - Para as 36 posições, criar botões com `LibStub("LibActionButton-1.0"):CreateButton(...)` num header seguro.
  - A fileira 1, colunas 1–12, recebe `SetState` para as páginas 1–14, usando `RegisterStateDriver(header, "page", Data.PagingDriver())`.
  - Cada botão é posicionado com `HUD.Place` nas coordenadas do spec 4.2. Os da metade direita usam `MirrorX`.
- [ ] **Passo 2: Pele.**
  - O ícone é recortado com `SetTexCoord(.08,.92,.08,.92)` e não leva borda própria, porque a moldura já está na textura do HUD.
  - Tecla no canto superior direito, em fonte de 9 px e cor `#e8dcc0`.
  - Contagem de cargas e de itens, cooldown nativo com números e realce de proc.
- [ ] **Passo 3: Atalhos.** Em `PLAYER_LOGIN` e `UPDATE_BINDINGS`, `SetOverrideBindingClick` faz cada `binding` de `ACTION_LAYOUT` apontar para o seu botão.
- [ ] **Passo 4: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 5: Commit.** Mensagem: `feat: 36-button central action bar with paging`.
- [ ] **Passo 6: PONTO DE VERIFICAÇÃO (usuário).**
  - As teclas 1–0, `-` e `=` funcionam.
  - Arrastar uma magia para um botão funciona.
  - Montar num veículo: a fileira 1 troca de página.
  - Druida em forma de urso ou felino: a barra troca.
  - Os cooldowns aparecem.

### Tarefa 7: Barras verticais e página de configurações

**Files:**
- Create: `ObsidianUI/HUD/VerticalBars.lua`, `ObsidianUI/Settings/Settings.lua`
- Modify: `.toc`

**Interfaces:**
- **Consumes:** `ActionBars.CreateButton`, `Data.VBAR1`/`VBAR2`, `ns.db`, `ns.RunOutOfCombat`.
- **Produces:**
  - `ns.VerticalBars.Refresh()`, que lê `ns.db.vbar1` e `ns.db.vbar2`.
  - Categoria `ObsidianUI` no painel de Configurações do jogo.

- [ ] **Passo 1: `Refresh`.**
  - Nenhuma barra ligada: esconde tudo.
  - Uma ligada: mostra a textura `vbar1` com 12 botões.
  - As duas ligadas: mostra **só** a textura `vbar2`, que é a peça única, com 24 botões.
  - A ancoragem é `RIGHT` do UIParent, centralizada entre o minimapa e o orbe direito, com altura de 42% da tela.
  - Tudo dentro de `RunOutOfCombat`.
- [ ] **Passo 2: `Settings.lua`.**
  - `Settings.RegisterVerticalLayoutCategory("ObsidianUI")`.
  - Dois checkboxes: "Barra vertical direita 1" e "Barra vertical direita 2".
  - Slider "Escala do HUD" de 0.6 a 1.4, em passos de 0.05.
  - Cada mudança grava em `ns.db` e chama `VerticalBars.Refresh` ou o resize do HUD.
- [ ] **Passo 3: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 4: Commit.** Mensagem: `feat: optional joined vertical bars and settings page`.
- [ ] **Passo 5: PONTO DE VERIFICAÇÃO (usuário).**
  - Ligar só a 1: aparece uma coluna.
  - Ligar as duas: aparece uma peça só, sem moldura no meio.
  - Ligar uma barra em combate: ela aparece ao sair do combate, sem erro de "ação bloqueada".

### Tarefa 8: Painéis de menu 3×3

**Files:**
- Create: `ObsidianUI/HUD/MenuPanels.lua`
- Modify: `.toc`

**Interfaces:**
- **Consumes:** `Data.MENU_LEFT`/`MENU_RIGHT`, `Resolve.First`, `ns.HUD.Place`.
- **Consumes da Tarefa 16:** `ns.Inventory.Toggle()`. Até a Tarefa 16 ficar pronta, usar um stub que chama `ToggleAllBags()`.

- [ ] **Passo 1: Botões de menu.**
  - Um botão `SecureActionButtonTemplate` com `type="click"` e `clickbutton = Resolve.First(entry.candidates)`.
  - Exceção: `character` chama `ns.Inventory.Toggle()`.
  - Se nenhum candidato existir, o botão fica escondido.
  - Ícone: o atlas ou a textura do micro botão, com `SetDesaturated(true)` e `SetVertexColor(0.91,0.77,0.42)`.
  - Tooltip com o nome.
- [ ] **Passo 2: Botões de bolsa (painel direito).**
  - Ícone: `GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bag))`.
  - Clique abre `ns.Inventory.Toggle()`.
  - `OnReceiveDrag` chama `PutItemInBag(invID)`.
  - Tooltip com `GameTooltip:SetInventoryItem`.
  - Os botões Social, Procurar Grupo e PvP usam micro botões.
- [ ] **Passo 3: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 4: Commit.** Mensagem: `feat: menu panels`.

### Tarefa 9: Barras especiais (postura, pet, botão extra, zona, sair do veículo)

**Files:**
- Create: `ObsidianUI/HUD/SpecialBars.lua`
- Modify: `.toc`

- [ ] **Passo 1: Reposicionar os frames da Blizzard** resolvidos por `Data.FRAME_CANDIDATES`. Tudo em `RunOutOfCombat`, com `hooksecurefunc(f, "SetPoint", reapply)` para que o Edit Mode não traga o frame de volta.
  - **Barra de postura:** centrada acima da barra de ações, deslocada à esquerda.
  - **Barra de pet:** mesma altura, deslocada à direita.
  - **Botão extra e habilidade de zona:** centrados acima da barra de conjuração.
  - **Sair do veículo:** à direita da barra de conjuração.
- [ ] **Passo 2: Pele.** Esconder as artes de fundo da Blizzard (`.Background`, `.Border`, `NormalTexture`) e aplicar `aura_border` em bronze.
- [ ] **Passo 3: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 4: Commit.** Mensagem: `feat: reposition stance/pet/extra/vehicle bars`.
- [ ] **Passo 5: PONTO DE VERIFICAÇÃO (usuário).**
  - Caçador ou bruxo com pet: a barra de pet aparece.
  - Guerreiro ou druida: a barra de postura aparece.
  - Numa missão com botão extra: o botão aparece no lugar certo.

### Tarefa 10: Alvo, foco, alvo do alvo, pet e debuffs no alvo

**Files:**
- Create: `ObsidianUI/HUD/UnitFrames.lua`
- Modify: `.toc`

**Interfaces:**
- **Consumes:** `Data.TARGET`, `Media.Apply("target_frame")`, `Media.Apply("ring_thin")`, `Layout.Rect`.
- **Produces:** `ns.UnitFrames.Create(unit, kind)`, com `kind` igual a `"large"`, `"small"` ou `"tiny"`.

- [ ] **Passo 1: Frames `large` (target) e `small` (focus).**
  - São botões `SecureUnitButtonTemplate` com `RegisterUnitWatch` e cliques `type1="target"` e `type2="togglemenu"`.
  - O alvo usa `target_frame`, com largura de 0.46×altura da tela. O foco usa `focus_frame`, com largura de 0.20×altura, e as medidas vêm do spec 7.1.
  - **Retrato:** `SetPortraitTexture` com máscara circular, no furo do spec 4.6.
  - **Anel:** `ring_thin` tingido pela classificação, usando `UnitClassification`: `elite`/`worldboss` em `#a335ee`, `rare`/`rareelite` em `#c0c0c0`, e invisível nos outros casos.
  - **Nome, nível e classificação:** na placa.
  - **Barras:** StatusBars de vida e de recurso nas posições do spec.
  - **Texto da vida:** porcentagem mais o valor abreviado.
  - **Posição:** alvo no topo esquerdo; foco logo abaixo dele.
- [ ] **Passo 2: Frames `tiny` (targettarget e pet).**
  - Textura `unit_small` com largura de 0.17×altura da tela. Usar o furo, o nome, a vida e o recurso nas medidas do spec 7.1.
  - O alvo do alvo fica à direita do alvo. O pet fica acima do orbe de vida.
- [ ] **Passo 3: Debuffs no alvo.**
  - Uma fileira de até 8 ícones de 22 px, colada embaixo das barras do alvo.
  - Usa `C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL|PLAYER")`.
  - Mostra o cooldown nativo e a contagem de acúmulos, com borda `#c4251c`.
  - Atualiza em `UNIT_AURA`, quando a unidade é `target`, e em `PLAYER_TARGET_CHANGED`.
- [ ] **Passo 4: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 5: Commit.** Mensagem: `feat: target/focus/tot/pet frames and target debuffs`.
- [ ] **Passo 6: PONTO DE VERIFICAÇÃO (usuário).**
  - Mirar num elite: aparece o anel roxo.
  - Os seus DoTs aparecem embaixo do alvo.
  - `/focus` mostra o quadro de foco.
  - Clique direito abre o menu.

### Tarefa 11: Barra de conjuração e recurso de classe

**Files:**
- Create: `ObsidianUI/HUD/CastBar.lua`, `ObsidianUI/HUD/ClassResource.lua`
- Modify: `.toc`

**Interfaces:**
- **Consumes:** `Data.ClassResourceFor`, `Resolve.First(Data.FRAME_CANDIDATES.castbar)`.

- [ ] **Passo 1: `CastBar.lua`.**
  - Reaproveita o frame de conjuração do jogador da Blizzard. É reposicionado centralizado acima do HUD, com largura de 22% da tela e altura de 2.6%.
  - Pele: textura `castbar` por trás e preenchimento `bar_fill` tingido de `#ffcf6a` para `#b86a12` dentro da ranhura do spec 7.1. Ícone no encaixe da esquerda e texto dentro da barra.
  - Interrompida: preenchimento `#c4251c`.
- [ ] **Passo 2: `ClassResource.lua`.**
  - Até 10 gemas `gem_off`/`gem_on` de 0.033×altura da tela, centralizadas entre a barra de conjuração e a barra de ações.
  - Em `PLAYER_SPECIALIZATION_CHANGED`, `UNIT_DISPLAYPOWER` e `UPDATE_SHAPESHIFT_FORM`, recalcula `ClassResourceFor(...)`. Se o resultado for `nil`, esconde as gemas.
  - Em `UNIT_POWER_FREQUENT`: se `issecretvalue(UnitPower(...))` for falso, acende as gemas de 1 a N. Se for verdadeiro, ativa o **fallback**: reaproveita o frame de recurso de classe da Blizzard e o reposiciona no mesmo lugar.
  - A cor da gema vem de `CLASS_RESOURCE`.
- [ ] **Passo 3: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 4: Commit.** Mensagem: `feat: castbar skin and class resource gems`.

### Tarefa 12: Buffs e debuffs do jogador (topo central)

**Files:**
- Create: `ObsidianUI/HUD/Auras.lua`
- Modify: `.toc`

- [ ] **Passo 1: Dois `SecureAuraHeaderTemplate`.**
  - Atributos: `unit="player"`, `filter="HELPFUL"` ou `"HARMFUL"`, `template="ObsidianUIAuraTemplate"` (definido por `CreateFrame` em Lua via `SecureHandlerWrapScript`, ou num XML mínimo), `point="TOP"`, `xOffset=30`, `wrapAfter=16`, `sortMethod="TIME"`, `sortDirection="-"`.
  - Os buffs ficam em `TOP` do UIParent, com y -2.5%. Os debuffs ficam com y -9.5%.
- [ ] **Passo 2: Botão de aura.**
  - Ícone de 26 px com borda `aura_border`: bronze para buff e `#c4251c` para debuff.
  - Cooldown nativo com contagem regressiva e número de acúmulos.
  - Clique direito cancela, que é o comportamento padrão do header.
- [ ] **Passo 3: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 4: Commit.** Mensagem: `feat: player auras at top center`.

### Tarefa 13: Minimapa com borda mínima

**Files:**
- Create: `ObsidianUI/HUD/Minimap.lua`
- Modify: `.toc`

- [ ] **Passo 1: Contêiner.**
  - Frame no `TOPRIGHT`, com -1.4% e -3.5% de deslocamento e lado de 12% da largura da tela.
  - `Minimap:SetParent(container)`, `Minimap:SetMaskTexture(mask_circle)` e `Minimap:SetAllPoints`.
  - Esconder o `MinimapCluster` e as bordas padrão.
  - `minimap_ring` por cima, como a única borda. A máscara do mapa vai no furo do spec 7.1.
- [ ] **Passo 2: Plaquinha da zona.**
  - `#16171b`, borda `#8a6d3b`, cantos arredondados e fonte serifada de 10 px `#e8c46a`.
  - Texto de `GetMinimapZoneText()`. Atualiza em `ZONE_CHANGED*`.
  - Fica centralizada no topo da borda.
- [ ] **Passo 3: Os 4 encaixes da textura** (centros no spec 7.1) recebem por reparent o relógio, o correio, o rastreamento e o calendário, resolvidos por `FRAME_CANDIDATES`, cada um com um quadrado de 56 da textura.
- [ ] **Passo 4: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 5: Commit.** Mensagem: `feat: minimal minimap`.

### Tarefa 14: Posições padrão dos frames que continuam

**Files:**
- Create: `ObsidianUI/HUD/DefaultPositions.lua`
- Modify: `.toc`

- [ ] **Passo 1: Na primeira carga do personagem** (flag `ns.db.positioned`), em `RunOutOfCombat`:
  - **Chat (`ChatFrame1`):** canto inferior esquerdo, acima do topo do HUD mais 8 px. Usar `FCF_SavePositionAndDimensions`.
  - **Rastreador de missões:** à direita, entre a base do minimapa e o topo das barras verticais.
  - **Alertas:** centro-alto.
  - Depois disso, as posições ficam com o usuário e com o Edit Mode.
- [ ] **Passo 2: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 3: Commit.** Mensagem: `feat: default positions clear of the HUD`.
- [ ] **Passo 4: PONTO DE VERIFICAÇÃO DO HUD COMPLETO (usuário).** Comparar com o mockup `hud-meshy-v11.html`:
  - Nada se sobrepõe.
  - Uma sessão de combate de 5 minutos termina sem erros de Lua (`/console scriptErrors 1`).

### Tarefa 15: Filtros e modelo da grade (puros)

**Files:**
- Create: `ObsidianUI/Inventory/Filters.lua`, `ObsidianUI/Inventory/GridModel.lua`, `tests/test_inventory_model.py`

**Interfaces:**
- **Produces:**
  - `ns.Filters.Category(classID, bagID)` retorna `"equip"`, `"consumable"`, `"material"`, `"reagent"` ou `"other"`.
  - `ns.Filters.TABS = { "all", "equip", "consumable", "material", "reagent" }`, com os rótulos "Tudo", "Equip.", "Consum.", "Materiais" e "Reagentes".
  - `ns.GridModel.Build(slots, tab)`: recebe uma lista `{bag, slot, classID}`, cujos itens vazios têm `classID=nil`, e devolve a lista ordenada visível.
  - `ns.GridModel.Rows(n, cols)` retorna `ceil(n/cols)`, com mínimo de 6.
  - `ns.GridModel.Pos(index, cols)` retorna `col, row`, começando em 1.

- [ ] **Passo 1: Escrever os testes que falham.**
  - `test_category`:
    - Classes 2 e 4 dão `equip`.
    - Classe 0 dá `consumable`.
    - Classes 7, 5, 3 e 8 dão `material`.
    - Qualquer item com `bagID == 5` (bolsa de reagentes) dá `reagent`.
    - `classID=nil` dá `other`.
  - `test_build_all_keeps_bag_order`: na aba `all`, a ordem segue bolsa 0..5 e depois slot, e inclui os slots vazios.
  - `test_build_filter_excludes_empty`: na aba `equip`, só aparecem itens `equip`, sem os vazios.
  - `test_grid_rows_min_and_growth`: `Rows(10,8)` dá 6, `Rows(48,8)` dá 6, `Rows(49,8)` dá 7 e `Rows(160,8)` dá 20.
  - `test_grid_handles_missing_bag`: se a lista não tem nenhum slot da bolsa 5, `Build(slots, "reagent")` devolve `{}` sem erro.
  - `test_pos`: `Pos(1,8)` dá `1,1`, `Pos(8,8)` dá `8,1` e `Pos(9,8)` dá `1,2`.
- [ ] **Passo 2: Rodar `pytest tests/test_inventory_model.py -q`.** Resultado esperado: FAIL.
- [ ] **Passo 3: Implementar.**
- [ ] **Passo 4: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 5: Commit.** Mensagem: `feat: inventory filters and grid model`.

### Tarefa 16: Janela do inventário (modelo 3D, equipamento e atributos)

**Files:**
- Create: `ObsidianUI/Inventory/Window.lua`
- Modify: `.toc`, `ObsidianUI/HUD/MenuPanels.lua` (trocar o stub de `ns.Inventory.Toggle`)

**Interfaces:**
- **Consumes:** `Data.INV`, `Data.EQUIP_*`, `Data.WEAPONS`, `Media.Apply("inventory")`, `Layout.Rect`.
- **Produces:**
  - `ns.Inventory.frame`.
  - `ns.Inventory.Toggle()`, `ns.Inventory.Open()`, `ns.Inventory.Close()`.
  - `ns.Inventory.gridArea`: um frame que cobre a área da grade no spec 4.10. É usado pela Tarefa 17.

- [ ] **Passo 1: Janela.**
  - Altura de 72% da tela e largura proporcional a 690×1334.
  - Ancorada à direita, centralizada na vertical. Pode ser arrastada pelo título.
  - Entra em `UISpecialFrames`, para fechar com ESC.
  - Título "Personagem" na placa.
- [ ] **Passo 2: Modelo 3D.**
  - `CreateFrame("PlayerModel")` na área do spec. Em `OnShow`, chamar `SetUnit("player")`. O fundo fica transparente.
  - Arrastar com o botão esquerdo chama `SetFacing`. A rodinha controla `SetPortraitZoom`, de 0 a 0.6.
  - `SetLight` com luz quente.
  - Atualiza em `PLAYER_EQUIPMENT_CHANGED` e `UNIT_MODEL_CHANGED` (player).
- [ ] **Passo 3: Slots de equipamento.**
  - Botões nas posições do spec 4.10, em que as armas são quadradas de 100 com recuo de 9. Usar `GetInventorySlotInfo(name)` dentro de `pcall`. Se `RangedSlot` não existir, o slot fica escondido.
  - Ícone: `GetInventoryItemTexture`. Borda: cor de raridade, de `GetInventoryItemQuality`.
  - Clique esquerdo chama `PickupInventoryItem`. Shift-clique insere o link no chat.
  - `OnEnter` chama `GameTooltip:SetInventoryItem`.
- [ ] **Passo 4: Coluna de atributos recolhível.**
  - Um botão "Atributos" na lateral da janela abre um painel de 180 px colado à esquerda, com fundo `#16171b` e borda `#8a6d3b`.
  - Mostra: `UnitStat` 1–5 (os que existirem), armadura (`UnitArmor`), crítico (`GetCritChance`), aceleração (`GetHaste`) e, se existir, maestria (`GetMasteryEffect`).
  - Botões pequenos "Reputação" e "Moedas" abrem as janelas da Blizzard via `ToggleCharacter("ReputationFrame")` e `ToggleCharacter("TokenFrame")`.
- [ ] **Passo 5: Tecla C.** Usar hook em `ToggleCharacter` só para `"PaperDollFrame"`, que passa a abrir a janela nova. As outras abas continuam indo para a Blizzard.
- [ ] **Passo 6: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 7: Commit.** Mensagem: `feat: inventory window with 3D model, gear and stats`.

### Tarefa 17: Grade de bolsas, abas, rolagem, rodapé

**Files:**
- Create: `ObsidianUI/Inventory/BagGrid.lua`
- Modify: `.toc`

**Interfaces:**
- **Consumes:** `ns.Inventory.gridArea`, `ns.Filters`, `ns.GridModel`, `Data.INV`.

- [ ] **Passo 1: Contêineres e botões.**
  - Um frame oculto por bolsa (0–5), com `SetID(bagID)`.
  - Botões `ContainerFrameItemButtonTemplate` com `SetID(slot)`.
  - São pré-criados fora de combate até `C_Container.GetContainerNumSlots` de cada bolsa. Botões novos só são criados fora de combate.
- [ ] **Passo 2: ScrollFrame na `gridArea`.**
  - Passo entre slots: 72×77.5 px da textura, convertido por `Layout.Rect`. Visíveis: 8×6.
  - A altura do filho é `Rows(n,8)` vezes o passo.
  - Barra de rolagem fina em bronze.
  - **Re-layout** com `GridModel.Build` + `Pos` em `BAG_UPDATE_DELAYED`, na troca de aba e ao abrir. Se estiver em combate, o re-layout vai para a fila de `RunOutOfCombat`, e a ordem atual continua até lá.
- [ ] **Passo 3: Abas e rodapé.**
  - **Abas:** 5 botões de texto nas posições do spec. A ativa fica em `#ffd100`.
  - **Rodapé:** 5 botões de bolsa com a mesma lógica da Tarefa 8 e o ouro (`GetMoneyString(GetMoney(), true)`) na placa.
- [ ] **Passo 4: Substituir as bolsas padrão.**
  - Hooks em `ToggleAllBags`, `OpenAllBags`, `CloseAllBags`, `ToggleBackpack` e `OpenBackpack` abrem e fecham `ns.Inventory`.
  - Esconder `ContainerFrameCombinedBags` e `ContainerFrame1..N`.
- [ ] **Passo 5: Rodar `pytest -q`.** Resultado esperado: PASS.
- [ ] **Passo 6: Commit.** Mensagem: `feat: bag grid with tabs, scroll and footer`.
- [ ] **Passo 7: PONTO DE VERIFICAÇÃO FINAL (usuário).**
  - B e C abrem a mesma janela.
  - Clicar com o botão direito num item usa o item.
  - Arrastar um item para um slot de equipamento equipa.
  - Trocar uma bolsa por uma maior acrescenta linhas, e a rolagem funciona.
  - A aba Reagentes mostra só a bolsa de reagentes.
  - Abrir as bolsas em combate funciona.
  - Comparar com o mockup `inventario-pedra.html`.
