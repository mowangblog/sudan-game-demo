# 摄政王的游戏 — AI 出图提示词清单

> 配套文档：`.workbuddy/plans/cosmic-vortex-turing.md`（替换计划，含逐文件代码位置）。
> 本清单为**出图用提示词库**：每个资产给出【文件名 / 分辨率 / 对应代码位置 / 英文提示词】。已确认决策：卡牌用 **Tier1（4 档 rank 底图）**，配色统一到**调色板 A（手牌暗灰）**。
> 直接用英文提示词丢进图像模型即可；中文为给你的说明。

---

## 0. 通用使用说明

- **所有提示词共用前缀**（见 §1），可复制拼接。
- **分辨率约定**：卡牌/立绘 `512×768`（2:3 竖）；图标 `256×256`；边框/按钮 `512×512`（九宫格，四角留 64px 不可拉伸花纹，中间纯色可拉伸）；整幅背景 `1920×1080`。
- **透明背景**：图标、边框、按钮、星标类一律要求 `transparent background`；卡牌底图可保留暗色底（不透明）或透明由代码叠。
- **版权**：本项目已因版权从《苏丹的游戏》改名为《摄政王的游戏》，**禁止复制任何原版美术**，提示词已加负向约束。
- **代码位置**引用计划 §1 的表，便于出图后知道接去哪。

---

## 1. 全局风格与配色（所有提示词的前缀 + 负向）

**风格前缀（拼到每个提示词前面）：**
```
ornate dark fantasy royal court game UI asset, gilded gold trim (color #c8a84e), dark aged wood and parchment textures, moody atmospheric lighting, highly detailed, clean anti-aliased edges,
```

**负向约束（加在结尾）：**
```
NOT copying any existing commercial game art, no text, no letters, no UI widgets, no watermark, no signature,
```

**调色板 A（卡牌/边框底色，已统一）：**
| rank | 名称 | 十六进制 | 描述 |
|---|---|---|---|
| STONE | 岩石 | `#26211C` | 暗岩石灰黑，粗糙石面 |
| BRONZE | 青铜 | `#21291A` | 暗铜绿，铜锈 |
| SILVER | 白银 | `#1F2126` | 暗银蓝，冷调 |
| GOLD | 黄金 | `#292414` | 暗金棕，金箔 |

全局金：`GOLD #c8a84e` / 亮金 `#e8d48b` / 暗金 `#8a6820`；文字米色 `#f0e6c8`；类型色：欢愉品红 `#8b3a5c`、奢靡蓝 `#3a5c8b`、征伐绿 `#3a5b3a`、杀戮暗红 `#6b2a2a`。

---

## 2. 主菜单（`scripts/ui/MainMenu.gd`）

| 文件名 | 分辨率 | 代码位置 | 提示词 |
|---|---|---|---|
| `ui/main_menu_bg.png` | 1920×1080 | `:31` | `${前缀} full-screen background for a fantasy royal court game main menu, dim throne-room silhouette, arches and hanging banners in shadow, vignette edges, deep blacks with gold #c8a84e accents, empty center for text, cinematic, ${负向}` |
| `ui/title_emblem.png` | 512×256 透明 | `:41` | `${前缀} symmetrical royal crest emblem, ornamental gold filigree, a regent's crown motif, dark background, transparent, logo decoration, ${负向}` |
| `ui/menu_button.png` | 512×512 九宫格 | `:63-82` | `${前缀} ornate gold-bordered button panel, dark parchment center, beveled gilded frame #c8a84e, transparent center, nine-slice safe border, ${负向}` |

---

## 3. UI 框架 / 边框（全部 `StyleBoxFlat` → `StyleBoxTexture`）

| 文件名 | 分辨率 | 代码位置 | 提示词 |
|---|---|---|---|
| `ui/statusbar_bg.png` | 512×128 九宫格 | `StatusBar.gd:30-40` | `${前缀} thin top status bar strip, dark wood with subtle gold #c8a84e lower border line, transparent, ${负向}` |
| `ui/sorceress_panel.png` | 512×512 九宫格 | `SorceressScene.gd:94-103` | `${前缀} large ornate popup window frame, dark parchment interior, heavy gilded gold #c8a84e border with corner flourishes, drop shadow, transparent center, ${负向}` |
| `ui/sorceress_portrait_frame.png` | 512×768 透明 | `SorceressScene.gd:114-122` | `${前缀} vertical portrait frame, mauve-tinted (#8b3a5c) translucent ornate border, fantasy sorceress theme, transparent center, ${负向}` |
| `ui/cardbox_frame.png` | 512×512 九宫格 | `CardBox.gd:16-25` | `${前缀} wooden treasure chest / scroll box frame, dark wood with gold #c8a84e filigree, mystical, transparent center, ${负向}` |
| `ui/cardbox_card_frame.png` | 512×768 九宫格 | `CardBox.gd:76-101` | `${前缀} centered large card display frame, ornate gold #c8a84e border, dark interior, transparent center, ${负向}` |
| `ui/map_board.png` | 1920×1080 | `MapRitePanel.gd:24-38` | `${前缀} fantasy city map board background, aged parchment with faint district outlines, gold #c8a84e coastlines, dark moody, ${负向}` |
| `ui/rite_popup_frame.png` | 512×512 九宫格 | `RiteDetailPopup.gd:70-90` | `${前缀} ritual configuration popup frame, two-panel hint, dark parchment, gold #c8a84e border, transparent center, ${负向}` |
| `ui/rite_panel_inner.png` | 512×256 九宫格 | `RiteDetailPopup.gd:102-116,230-244` | `${前缀} inner sub-panel frame, thin gold #8a6820 border, dark, transparent center, ${负向}` |
| `ui/settlement_frame.png` | 512×512 九宫格 | `SettlementScreen.gd:92-116` | `${前缀} settlement screen outer frame, dark with gold #c8a84e border, ornate, transparent center, ${负向}` |
| `ui/settlement_dice_tray.png` | 256×256 九宫格 | `SettlementScreen.gd:92-116` | `${前缀} dice tray panel, dark recessed area, thin gold border, transparent center, ${负向}` |
| `ui/popup_frame_generic.png` | 512×512 九宫格 | `PopupManager.gd` | `${前缀} generic small popup frame, dark parchment, gold #c8a84e border, transparent center, ${负向}` |
| `ui/cardzone_border.png` | 512×128 九宫格 | `MainScene.gd:391-401` | `${前缀} horizontal hand-card zone divider border, gold #8a6820 thin line, dark, transparent, ${负向}` |
| `ui/insight_bubble.png` | 256×128 九宫格 | `InsightController.gd:128-140` | `${前缀} small speech bubble frame, dark with thin gold #8a6820 border, transparent center, ${负向}` |

---

## 4. 按钮（5 家族，共用少量纹理 + 三态）

| 文件名 | 分辨率 | 代码位置 | 提示词 |
|---|---|---|---|
| `ui/btn_gold_normal.png` | 512×512 九宫格 | 家族 A（`MainScene.gd:101-114` 默认主题）| `${前缀} gold-bordered button, normal state, dark parchment center #2a1c0a, beveled gilded frame #8a6820, transparent center, ${负向}` |
| `ui/btn_gold_hover.png` | 512×512 九宫格 | 同上 hover | `${前缀} gold-bordered button, hover state, brighter parchment #3a2c0a, glowing gold #e8d48b frame, transparent center, ${负向}` |
| `ui/btn_gold_pressed.png` | 512×512 九宫格 | 同上 pressed | `${前缀} gold-bordered button, pressed state, sunk dark center, strong gold #e8d48b inner glow, transparent center, ${负向}` |
| `ui/btn_menu_large.png` | 512×256 九宫格 | 家族 B（`MainMenu.gd:63-82`）| `${前缀} large menu button, 240x48 feel, ornate gold #c8a84e border, dark center, transparent, ${负向}` |
| `ui/btn_sorceress.png` | 512×128 九宫格 | 家族 D（`SorceressScene.gd:517-543`）| `${前缀} slim dialogue button, gold #8a6820 border, dark center #2a1810, transparent, ${负向}` |
| `ui/btn_map_node.png` | 512×128 九宫格 | 家族 E（`MapRitePanel.gd:159-172`）| `${前缀} bottom-only gold underline button, dark, thin gold #8a6820 bottom border, transparent, ${负向}` |

---

## 5. 图标（全部 `256×256` 透明 PNG，替换 emoji）

| 文件名 | 含义 | 代码位置 | 提示词 |
|---|---|---|---|
| `icons/type_lust.png` | 欢愉 | `RiteSlotDrop.gd:27` 等 | `${前缀} small icon of a chalice with a heart, mauve #8b3a5c glow, fantasy, transparent, ${负向}` |
| `icons/type_luxury.png` | 奢靡 | 同上 | `${前缀} small icon of a gem-encrusted coin pile, blue #3a5c8b glow, fantasy, transparent, ${负向}` |
| `icons/type_conquest.png` | 征伐 | 同上 | `${前缀} small icon of crossed swords / banner, green #3a5b3a glow, fantasy, transparent, ${负向}` |
| `icons/type_murder.png` | 杀戮 | 同上 | `${前缀} small icon of a dagger dripping, dark red #6b2a2a glow, fantasy, transparent, ${负向}` |
| `icons/attr_body.png` | 体魄 | `MainScene.gd:18` 等 | `${前缀} small icon of a muscular arm / shield, monochrome gold, transparent, ${负向}` |
| `icons/attr_combat.png` | 战斗 | 同上 | `${前缀} small icon of a sword, monochrome gold, transparent, ${负向}` |
| `icons/attr_survival.png` | 生存 | 同上 | `${前缀} small icon of a leaf + flame, monochrome gold, transparent, ${负向}` |
| `icons/attr_social.png` | 社交 | 同上 | `${前缀} small icon of two linked rings, monochrome gold, transparent, ${负向}` |
| `icons/attr_charm.png` | 魅力 | 同上 | `${前缀} small icon of a mirror / rose, monochrome gold, transparent, ${负向}` |
| `icons/attr_stealth.png` | 隐匿 | 同上 | `${前缀} small icon of a hood / shadow, monochrome gold, transparent, ${负向}` |
| `icons/attr_wisdom.png` | 智慧 | 同上 | `${前缀} small icon of an open book / eye, monochrome gold, transparent, ${负向}` |
| `icons/attr_magic.png` | 魔力 | 同上 | `${前缀} small icon of a spark / rune, monochrome gold, transparent, ${负向}` |
| `icons/res_gold.png` | 金币 | `ResourceCardManager.gd` 等 | `${前缀} small icon of a gold coin with regent crest, #c8a84e, transparent, ${负向}` |
| `icons/item.png` | 物品 | `RiteSlotDrop.gd` | `${前缀} small icon of a magnifier over a trinket, monochrome gold, transparent, ${负向}` |
| `icons/intel_insight.png` | 洞察 | `ResourceCardManager.gd:158-169` | `${前缀} small icon of an open eye, monochrome gold, transparent, ${负向}` |
| `icons/intel_secret.png` | 秘氛 | 同上 | `${前缀} small icon of a masked face, monochrome gold, transparent, ${负向}` |
| `icons/intel_chance.png` | 机遇 | 同上 | `${前缀} small icon of a four-leaf clover / dice, monochrome gold, transparent, ${负向}` |
| `icons/intel_inside.png` | 内幕 | 同上 | `${前缀} small icon of an ear at a door, monochrome gold, transparent, ${负向}` |
| `icons/intel_omen.png` | 预兆 | 同上 | `${前缀} small icon of a comet, monochrome gold, transparent, ${负向}` |
| `icons/intel_cult.png` | 密教 | 同上 | `${前缀} small icon of an occult sigil, monochrome gold, transparent, ${负向}` |
| `icons/rep_fame.png` | 名望 | `StatusBar.gd:54-60` | `${前缀} small badge icon of a laurel, green #5a9a5a, transparent, ${负向}` |
| `icons/rep_infamy.png` | 恶名 | 同上 | `${前缀} small badge icon of a broken shield, red #aa3030, transparent, ${负向}` |
| `icons/rep_power.png` | 权势 | 同上 | `${前缀} small badge icon of a crown, purple #9a6aba, transparent, ${负向}` |
| `icons/rep_chivalry.png` | 义名 | 同上 | `${前缀} small badge icon of a rising sun, blue #5a8aba, transparent, ${负向}` |
| `icons/rep_occult.png` | 灵知 | 同上 | `${前缀} small badge icon of an eye-in-triangle, green #6a8a5a, transparent, ${负向}` |
| `icons/dice_gold.png` | 金骰 | `StatusBar.gd:88` | `${前缀} small icon of a single die with a golden pip, #c8a84e, transparent, ${负向}` |
| `icons/book.png` | 书籍 | `CardFactory.gd:170` | `${前缀} small icon of a closed book with clasp, monochrome gold, transparent, ${负向}` |
| `icons/skull_insight.png` | 俺寻思 | `MainScene.gd:521` | `${前缀} small icon of a stylized skull with a thought spark, dark purple, transparent, ${负向}` |
| `icons/star.png` | 品级星 | `RG` 多处 | `${前缀} small five-point star, gold #e8d48b, transparent, ${负向}`（代码按 rank 复制 1~4 颗） |
| `icons/success.png` | 成功 | `SettlementScreen.gd` 等 | `${前缀} small checkmark seal, green, transparent, ${负向}` |
| `icons/fail.png` | 失败 | 同上 | `${前缀} small cross/X seal, red, transparent, ${负向}` |
| `icons/home.png` | 返回主菜单 | `PopupManager.gd:151` | `${前缀} small icon of a roof / home, monochrome gold, transparent, ${负向}` |
| `icons/close_x.png` | 关闭 | 多处 | `${前缀} small ornate X, monochrome gold, transparent, ${负向}` |
| `icons/reroll.png` | 重投 | `SettlementScreen.gd:173` | `${prefix} small icon of two circular arrows, monochrome gold, transparent, ${负向}` |

---

## 6. 立绘 / 肖像（最高优先替换）

| 文件名 | 分辨率 | 代码位置 | 提示词 |
|---|---|---|---|
| `portraits/sorceress.png` | 512×768 | `SorceressScene.gd:130-135` | `${前缀} full-body portrait of a mystical fantasy sorceress, ornate robe with mauve #8b3a5c and gold #c8a84e trim, mysterious aura, dark background, detailed face, regal, ${负向}` |
| `portraits/player.png` | 512×768 | `CardFactory.gd:25-78` | `${前缀} portrait of a neutral noble regent (player avatar), dark court attire with gold #c8a84e trim, plain background, ${负向}` |
| `portraits/meji.png` | 512×768 | 同上 | `${前缀} portrait of an elegant lady courtier, fantasy, dark background, gold-trimmed dress, ${负向}` |
| `portraits/zhaqiyi.png` | 512×768 | 同上 | `${前缀} portrait of a stern military officer, fantasy armor with gold trim, dark background, ${负向}` |
| `portraits/tietou.png` | 512×768 | 同上 | `${前缀} portrait of a burly loyal guard, fantasy, dark background, simple armor, ${负向}` |
| `portraits/kuaijiao.png` | 512×768 | 同上 | `${前缀} portrait of a clever scholar/advisor, fantasy robe, dark background, gold trim, ${负向}` |

---

## 7. 卡牌稀有度背景（核心，Tier1，调色板 A）

> 4 档底图，所有卡（摄政王令/角色/书）按 `rank` 复用同一张。边框亮度随品质提升：石→暗金，金→亮金 `#e8d48b`。类型强调色由代码叠加（见计划 §2.3），**底图不区分类型**。

| 文件名 | rank | 分辨率 | 代码位置 | 提示词 |
|---|---|---|---|---|
| `cards/ranks/stone.png` | 岩石 STONE | 512×768 | `CardFactory.gd` / `RiteSlotDrop.gd` / `CardBox.gd` / `SorceressScene.gd` | `${前缀} card background, dark rough stone surface color #26211C, carved cracks texture, subtle dark gold #8a6820 border, top and bottom ornate stone frame, empty center, vertical 2:3, ${负向}` |
| `cards/ranks/bronze.png` | 青铜 BRONZE | 512×768 | 同上 | `${前缀} card background, dark patinated bronze-green surface color #21291A, verdigris texture, thin gold #8a6820 border, top and bottom ornate frame, empty center, vertical 2:3, ${负向}` |
| `cards/ranks/silver.png` | 白银 SILVER | 512×768 | 同上 | `${前缀} card background, dark cool silver-blue surface color #1F2126, brushed metal sheen, elegant silver #aab4c8 border, top and bottom ornate frame, empty center, vertical 2:3, ${负向}` |
| `cards/ranks/gold.png` | 黄金 GOLD | 512×768 | 同上 | `${前缀} card background, dark rich gold-brown surface color #292414, gilded foil texture, bright gold #e8d48b ornate border with filigree, top and bottom luxurious frame, empty center, vertical 2:3, ${负向}` |

> 可选进阶（Tier2，本次不做）：`cards/sultan/<type>_<rank>.png` 共 16 张，在以上底图上加整幅类型插画（欢愉=享乐场景/奢靡=挥霍场景/征伐=战场/杀戮=暗杀），边框沿用对应 rank。

---

## 8. 地图 / 仪式节点

| 文件名 | 分辨率 | 代码位置 | 提示词 |
|---|---|---|---|
| `ui/map_board.png` | 见 §3 | `MapRitePanel.gd:24-38` | 已列 §3 |
| `ui/btn_map_node.png` | 见 §4 | `MapRitePanel.gd:159-172` | 已列 §4 家族 E |

---

## 9. 出图后接入代码的简要指引（待你决定实施时参考）

1. 建目录 `res://assets/images/{ui,icons,portraits,cards/ranks}`。
2. 新增 AutoLoad `scripts/autoload/ArtRegistry.gd`，按 `rank` 映射 4 张底图（见计划 §2.3 代码骨架）。
3. 卡牌渲染点（`CardFactory` 4 个 `make_*`、`CardBox.show_card_display`、`RiteSlotDrop` 两处、`SorceressScene._show_swap_card`）把 `StyleBoxFlat.bg_color = SC.get(rank)` 改为 `StyleBoxTexture(bg_texture=ArtRegistry.rank_bg(rank))`。
4. emoji `Label` 处改为 `TextureRect`（图标）/`TextureRect` 立绘，纹理走 `preload` 或 `ArtRegistry` 映射。
5. 边框/按钮 `StyleBoxFlat` 改为 `StyleBoxTexture`（九宫格，设 `region_rect` 与 `expand_margin_left/top/right/bottom`，**注意 Godot 4 用 `expand_margin_*` 而非 Godot 3 的 `margin_*`**）。

> 完整代码位置与改造清单见计划文件 `.workbuddy/plans/cosmic-vortex-turing.md` §1–§2。
