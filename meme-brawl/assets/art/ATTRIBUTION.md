# Reference attribution

The game atlas is a new generated pixel-art interpretation, not a copy of the reference sprite sheets. Character identities were checked against public fan projects; these sources do not establish the earliest meme upload or ownership of the underlying characters.

- **Daodun Pet contributors, “刀盾狗 Codex Pet”** — https://github.com/ztidal/codex-daodun-pet . The inspected fan artwork is offered under **CC BY 4.0**, https://creativecommons.org/licenses/by/4.0/ , subject to its stated third-party-rights limits. Used as visual reference to change our muscular humanoid dog into a low round Shiba with knife/shield; newly rendered in pixel art with fighting poses. Asset notice: https://github.com/ztidal/codex-daodun-pet/blob/main/LICENSE-ASSETS.md . No endorsement implied.
- **chunchiehhou, “奶蛙桌宠”** — https://github.com/chunchiehhou/naiwa-feidudu-niulai . Public visual reference for Naiwa's green eyes, pear silhouette, cream belly, and gray hands/feet. No code or image from the repository is redistributed here.
- **KevinKaslana093, “黄色生物·屋顶乱斗”** — https://github.com/KevinKaslana093/yellow-anomaly . Its explicitly AI-redrawn trio and documented character descriptions were inspected as secondary visual reference, not treated as original meme footage. No code or reference image is redistributed here.

See `sources.json` for exact reference commits and `../../docs/REFERENCE_RESEARCH.md` for excluded mismatching references and unresolved original audio.


## 六张主场精细背景与动态道具

`stages/*.png` 为按当前角色图集风格参考生成的原创 AI 素材；不是手工逐像素绘制，也未取用第三方游戏截图。原有角色图集用于描边、颗粒、体积与配色的风格对照。六张背景覆盖冰原、峡谷、零食荒原、沼泽、黄土坡、街巷；`props.png` 为带透明通道的六道具图集。猫与街巷背景单独移除可动脆角／箱体，使这些物件可在游戏中独立动画。

文件 SHA-256、生成源文件标识及图集区域位于 `stages/manifest.json`。运行仅需要仓库内的 PNG，不依赖生成服务。截图见 `meme-brawl/docs/stages`。
