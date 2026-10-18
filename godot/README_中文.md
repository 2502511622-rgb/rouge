# 光明之魂 1 · Godot 逆向工作台：真实画面恢复阶段

## 当前交付与边界

**这不是彻底完整逆向，也不是可完整通关的 Godot 移植。**
这次已运行上传的 ROM，确认其带中文汉化内容，进入开场村庄并执行移动、攻击和菜单操作。
与先前占位工程不同，默认场景现在显示从原 ROM 实际运行状态恢复的村庄。
原作背景、精灵、UI、调色板已分离，生成为 Godot 原生 TileMapLayer、TileSet 和 Sprite2D 节点，可直接编辑。
这些是真实检查点的静态画面，不是嵌入模拟器，也不是恢复了原作游戏循环。

## 打开和编辑

Godot 4.3+ 导入 `project.godot`；已在 Godot 4.6.3 导入测试。
主场景 `scenes/recovered_village.tscn`。运行后按 1/2/3 切换村庄/标题/对白；P 切换上一阶段的占位可玩原型。

在场景树中展开 `Viewport/Screen`：

- `BG0`～`BG3`：原始分层图块，TileMapLayer 可在 Godot 内直接改格子、调色板对应图块、位置等。
- `OBJ_*`：独立精灵节点，可移动、更换纹理或修改属性；`oam_attributes` 元数据保留属性证据。
- `assets/verified/`：真实颜色的图块图集、精灵、逐层图像、参考帧和独立重建帧。
- `assets/extracted/`：旧版启发式 LZ77 候选，不能将其灰度预览当成已确认图像。

原生场景中的坐标是**该检查点的显存/屏幕坐标**，不等于已恢复的整张世界地图。不可见或空白 OAM 项也保留。
默认场景中的主角不能行走；P 原型可行走，但该原型规则和素材仍是占位实现。

## 对照验证结果

`assets/verified/{title,village,dialogue}/scene.json` 记录比较方法、内存哈希、背景图块、OAM 属性及限制。
使用独立解码器从 VRAM/OAM/调色板重建三个检查点：每帧 38,400 像素，RGB 差异均为 **0**。
这只验证指定检查点的图像重建；不等于验证了所有场景、动画、颜色特效或 Godot 最终渲染的逐像素一致性。
标题检查点虽然颜色特效寄存器开启，当前静态帧仍恰好完全匹配；其他渐变帧未据此认定正确。

Godot 验证涵盖：原生 TileMapLayer 加载（村庄 16,384 个含循环副本的格子）、独立 OBJ 节点，以及旧原型的移动、编辑暂停、碰撞、攻击、经验、受伤和贴图加载。

## 可复现工具链

- `tools/gba_capture.c`：调用未经修改的 mGBA 0.10.5，执行输入脚本，保存帧、显存、调色板、OAM、RAM、CPU、状态，以及真实 BIOS SWI/DMA 参数。
- `analysis/runtime/*.scenario`：输入时序。按键位为 A=1、B=2、Select=4、Start=8、右=16、左=32、上=64、下=128、R=256、L=512。状态链和日志保留在分析目录。
- `tools/decode_snapshot.py SNAPSHOT_DIR OUTPUT_DIR`：Python + Pillow，独立重建 GBA mode 0 文本背景与 OBJ、比较模拟器参考帧。
- `tools/build_recovered_scenes.gd`：从解码结果生成真正可编辑的 Godot 场景。
- `tools/build_capture.sh`：编译前端；需自己提供 mGBA 0.10.5 源码与已配置构建目录。运行 Godot 工程本身不需要此工具或 mGBA。

mGBA 源码：https://github.com/mgba-emu/mgba ，固定提交 `26b7884bc25a5933960f3cdcd98bac1ae14d42e2`，MPL-2.0。
当前分析未使用外部 BIOS 文件，采用 mGBA 的 HLE BIOS。因此运行时观察仍应在其他合规模拟器/硬件上交叉验证。

```sh
sh tools/run_godot.sh --headless --editor --import
sh tools/run_godot.sh --headless -- --recovered-smoke
sh tools/run_godot.sh --headless -- --smoke-test
```

原始 ROM 未包含在交付包内。ROM 哈希、头部及初步分析见下方。

## 重放和原 ROM 字节定位

`analysis/replay_result.json`：从开机重放相同输入序列，村庄帧、VRAM、OAM、调色板与首次捕获逐字节相同。`tools/replay_capture.py` 提供重放入口。每个 session 日志中的 frame 从 0 重新计数；父状态链在脚本 route 中明确列出。

`analysis/rom_tile_byte_matches.json`：三个场景合计 1,851 项非平凡背景图块记录全部找到精确 ROM 字节匹配。相同图块可多处出现；这不是代码加载调用链证明。

## 尚未恢复

完整地图与关卡、全部角色和敌人动画、碰撞语义、职业/技能/装备/掉落公式、敌人 AI、战斗数值、任务事件、完整中文文本、音乐音效、存档格式、联机及流程一致性均未完成。
74 个具有宽高且满足 `payload = width * height * 8` 的块已列入 `analysis/dimensioned_blocks.json`，目前不能仅凭结构就认定为世界地图或碰撞。

---

以下保留第一阶段工具与 ROM 说明，旧主场景现在由 P 键进入：

# 光明之魂 1：Godot 逆向工作台（第一阶段）

这不是完整移植。当前交付包含 ROM 静态分析、候选图块提取、Godot 资源浏览器及独立编写的动作 RPG 测试场景。测试关卡、角色图形、敌人和数值使用占位实现，不是从原作恢复的玩法或资源。

## 打开与编辑

使用 Godot 4.3 或更新版本导入 `project.godot`，按 F6/F5 运行主场景/工程。已在 Godot 4.6.3 无界面模式通过功能测试。

- WASD/方向键移动；Space/J 攻击；Q 使用药水；R 重置。
- Tab 打开/关闭 ROM 图块浏览器，左侧选择块；预览为灰度 4bpp 解码，**不是已确认的原作图像**。
- F2 开启地图编辑，点击地面/墙体切换，F5 保存、F6 载入。运行窗口需有键盘焦点；Godot 编辑器也使用 F5/F6 启动命令。
- 运行时保存的地图在 Godot `user://edited_map.json`，不修改工程数据。修改 `data/prototype.json` 可持久编辑初始地图、移动速度和战斗数值。
- `scenes/player.tscn`、`scripts/player.gd`：玩家；`scripts/main.gd`：工作台、关卡、敌人和编辑器。

## 已验证事实

ROM：8,388,608 字节，标题 SHINING SOUL，代码 AHUJ，厂商 8P，版本 0，头部校验通过。
SHA-256：04489e661a493d4f5ef7e0a3e91e3c30094cbf4286cf2b6eee63479b4c3721ce。
AHUJ 提示日版，不足以确定是否汉化或修改。检测到 FLASH_V126 字符串，不代表已还原存档格式。

`analysis/rom_report.json` 和 `data/rom_manifest.json` 保存偏移、解压长度、哈希、候选指针引用和限制。
检测出 169 个结构上能通过解压检查、输出不短于输入的 LZ77 候选，已导出 `.bin` 和 `.png`。这些候选**不一定是图像**，也可能是字库、地图、表格或假阳性。仅扫描 4 字节对齐的 0x10 型数据、跳过已覆盖区间，因此不保证完整。
`raw4bpp_*.png` 是指定 ROM 区间的原始图块解释，未确认其用途。
所有预览均使用索引灰度，不包含经验证的原调色板或精灵拼接。

## 重新提取

Python 3 + Pillow：

```sh
python tools/extract_rom.py /path/to/光明之魂1.gba --out .
```

原 ROM 不在交付压缩包内。工程运行不需要 ROM。生成工具只读输入 ROM，重新生成候选输出。

## 测试

```sh
godot --headless --path . --editor --import
godot --headless --path . -- --smoke-test
```

云沙箱请使用 `tools/run_godot.sh --headless -- --smoke-test`，将 Godot 用户数据放到可写目录。
测试验证实际场景加载、贴图加载、碰撞、攻击、经验和受伤。没有验证原作行为一致性。
REA 的 `inspect-artifact` 对此文件报告 unsupported binary format，原始输出保存在 `analysis/rea-artifact.json`。没有声称 REA 自动反编译了 GBA 程序。

## 下一阶段

1. 用支持 GBA 的调试器建立可重复的启动/场景状态，记录 VRAM、OAM、调色板和 DMA 来源。
2. 对照 ROM 地址确认压缩块用途和可能的自定义资源头，恢复原始色彩、拼接和动画；不同 4bpp/8bpp/位图/地图格式必须分别验证。
3. 恢复地图索引、碰撞、事件、物品/职业/敌人数值；不能以占位值冒充原数据。
4. 追踪 ARM/Thumb 游戏循环和存档布局，为战斗/AI/任务建立对照样例后逐步移植。
5. 音乐、剧情、完整地图、联机和存档兼容性尚未实现。

请勿将此工作台视为“完整光明之魂 Godot 版”，也不要将输出资产的用途或正确性作未经验证的推断。
