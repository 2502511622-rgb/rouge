# 六角色音频

本次新增 **6 首原创循环 BGM、30 个角色专属技能提示音**。由 `tools/build_character_audio.py` 作曲与合成，不含采样录音；这不是原版梗声，也未声称已搜索或下载原视频。现有 19 个通用打击／材质声继续负责命中反馈。

| 角色 | 音乐 | 技能音色 |
| --- | --- | --- |
| 咕咕嘎嘎 | 128 BPM 冷调电子碎拍 | 调频鸣音、气流、短促音波 |
| 刀盾狗 | 116 BPM 工业鼓与金属贝斯 | 金属谐振、刀盾重击 |
| 妙脆角猫 | 96 BPM 怪诞拨弦 | 高频拨动、脆角颗粒 |
| 奶蛙 | 132 BPM 切分扭曲低音 | 低频摆动、黏液质感 |
| 牛来 | 88 BPM 重鼓与悲凉弦乐 | 低频震动、沉重冲击 |
| 美团袋鼠 | 124 BPM 街头电子放克 | 弹性低音、短促踢击提示 |

音乐跟随玩家所选角色，换角时交叉淡入淡出。每首 16 小节，尾音环绕到循环开头。技能音分为三个必杀、V／触发、CA；同一提示音至少间隔 0.22 秒，CA 间隔 1.2 秒。保留 4 个提示音声部与现有命中声部，避免无限叠加。

BGM 默认 -19 dB，台词或 CA 时降至 -28 dB，暂停／设置页降至 -32 dB，结束后恢复。已导入原版台词时只保留一个前景台词声部，音乐跟随实际播放时长压低。按 M 完全静音，恢复后重启当前曲目。原版台词仍可经现有 `import_voice.py` 导入，已登记录音角色计数保持真实，不将合成提示音计为录音。

素材清单、时长、BPM、峰值和 SHA-256 在 `assets/audio/characters/manifest.json`。重新生成需要 Python、NumPy 和 FFmpeg；常规运行直接使用随附 Ogg，无须重新生成。

```sh
cd /workspace/rouge/meme-brawl
python3 tools/build_character_audio.py
sh run.sh --headless --editor --import --quit
# Dummy 驱动验证播放状态和混音逻辑，不代表真人试听
 timeout 60 sh run.sh --headless --audio-driver Dummy --script res://tools/character_audio_check.gd
```

光明之魂 Godot 工程、Windows 游玩包、Switch 启动器及其 CI 已按用户要求从工作区清理。清理前可恢复副本位于 `/tmp/rouge-preserved/unrelated-projects.tar.gz`；它不是项目依赖，不应随项目发布。已有 Git 历史也保留。六张主场地图与环境技能联动已按新方案重新实现，见 HOME_STAGES.md。对战期间改用地图专属氛围音乐，菜单保留角色配乐。
