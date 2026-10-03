# 演示素材检查报告 / Demo validation

[中文首页](../README.md) · [English home](../README.en.md) · [素材列表 / Media](MEDIA.md) · [机器回执 / Manifest](evidence/media/manifest.json)

2026-10-03。对象为两版 28 秒演示、封面、图文教程截图及实际示例输出。此报告检查演示资料，不改变 Finder 组合键操作的产品验收状态；本轮没有修改应用源码。

Dated 2026-10-03. This report covers the two 28-second demos, covers, illustrated-guide captures, and actual sample exports. Media validation does not change physical Finder gesture acceptance. The tested app source is unchanged.

## 检查结果 / Results

| 检查 / Check | 竖屏 / Vertical | 横屏 / Horizontal | 方形封面 / Square cover |
| --- | --- | --- | --- |
| 规格 / Dimensions | 1080 × 1920 | 1920 × 1080 | 1080 × 1080 |
| 编码 / Codec | H.264 yuv420p + AAC | H.264 yuv420p + AAC | PNG |
| 时长与帧数 / Duration and frames | 28.000 s · 840 frames · 30 fps | 28.000 s · 840 frames · 30 fps | 1.4 s 时点静态导出 / still at 1.4 s |
| 完整视频解码 / Complete video decode | PASS · 0 errors | PASS · 0 errors | 不适用 / N/A |
| Fast Start / moov 在媒体前 | PASS | PASS | 不适用 / N/A |
| HyperFrames lint | 0 errors · 2 reviewed warnings | 0 errors · 2 reviewed warnings | 0 errors · 0 warnings |
| 页面运行检查 / Runtime | 0 errors · 0 warnings | 0 errors · 0 warnings | 0 errors · 0 warnings |
| 版面检查 / Layout | 0 findings | 0 findings | 0 findings |
| 字幕/文字对比度 / Caption/text contrast | 28 / 28 PASS | 28 / 28 PASS | 5 / 5 PASS |
| 每帧时间点素材来源 / Frame-timestamp provenance | 840 checked · 0 findings | 840 checked · 0 findings | 已审核的截图与实际输出 / approved captures and output |
| 编码后画面目视 / Encoded visual review | 逐秒 28 帧及全尺寸关键帧 / 28 one-second samples plus full-size keyframes | 同左 / same | 原尺寸目视 / full-size inspection |

两版视频各实际检查 55 个版面时点：5 个指定关键时点加 50 个转场时点，回执保留了实际列表。指定关键时点后，工具不再额外加入常规等间隔采样。转场候选超过上限的 197 个时点未进入自动版面检查，没有将它们写成检查通过。方形封面检查的是 1.4 秒静态画面。

Each video layout check actually covers 55 timestamps: five chosen keyframe times plus 50 transition timestamps. Reports retain the actual lists. Explicit keyframe times replace regular midpoint samples in this tool. Another 197 transition candidates were excluded by the cap and are not claimed as checked. The square cover was checked at the 1.4-second still.

## 告警与动效审查 / Warnings and motion review

每版的两项 `duplicate_media_discovery_risk` 来自同一实际输出图在三个场景复用、工具圆盘在两个场景复用。它们是独立场景中的图片节点，按固定时间线显示；逐帧来源检查和编码画面没有发现重复画面问题。告警按实保留，未改名绕过。

The two warnings per video concern one exported image reused in three scenes and a tool-wheel image reused in two scenes. Each node belongs to a separately timed scene. Provenance checks and encoded visual review found no duplicate-frame problem. Warnings remain in the receipts.

`check` 回执中的自动 motion 检查为 disabled，不能算作“自动动效全部通过”。本次另行生成并审查 [竖屏动效图](evidence/media/vertical-animation-map.json)、[横屏动效图](evidence/media/horizontal-animation-map.json) 和 [封面动效图](evidence/media/cover-animation-map.json)。每版视频 75 段 tween，图中展示 62 段，13 段微小变化按工具规则省略；指针出现/消失、点击环、同一窗口前后状态叠加和场景父节点淡入淡出属于有意编排。28 秒线性进度条是有意缓慢动画。封面 1–2 秒保持静态，用于导出静态图。

The automated motion pass is disabled in `check` and is not reported as passed. Motion was reviewed separately through animation maps and encoded frames. Each video has 75 tweens, 62 mapped and 13 micro-tweens omitted by the helper. Pointer fades, click rings, before/after overlays, ancestor scene fades, and the slow progress bar are intentional. The cover holds still during seconds 1–2 for still export.

## 隐私检查的准确范围 / Exact privacy scope

- 10 个原始应用截图/导出图做了 OCR 与目视检查，0 个私人绝对路径发现。[像素检查](evidence/media/source-pixels.json)
- 两版共 1680 个编码帧时间点检查浏览器时间线状态，图片只来自 8 个获准素材，显示的文件名只有 `Citrus Demo.pdf` 和 `Citrus Demo.jpg`。文字内容固定，未出现私人路径。[竖屏来源](evidence/media/vertical-frame-provenance.json) · [横屏来源](evidence/media/horizontal-frame-provenance.json)
- 该逐帧时间点检查核对的是文字节点和图片引用，并非对 MP4 每帧像素逐一 OCR。编码后的文件另做完整解码及逐秒抽帧目视检查。
- 对外包只包含专门制作的示例与应用窗口。没有工作桌面、文件选择器、最近文件列表、用户工作文件、用户原参考视频或 Tangerine 素材。机器回执里的本地绝对路径已移除。

Ten native captures/export images received OCR and visual review with no private absolute paths detected. At all 1680 video frame timestamps, the composition's text/image references were checked against eight approved assets and two demo filenames. This is a provenance audit, not pixel OCR of every MP4 frame. Encoded files separately received complete decode and one-second sampled visual review. Outward media excludes the work desktop, picker/recent lists, work files, the reference video, and Tangerine assets. Local absolute paths are removed from the published receipts.

## 实际功能与输出 / Actual app output

安装后的 1.0.1 通过“选择文件…”完成以下保存，脱敏回执见 [native-output-events.json](evidence/media/native-output-events.json)。示例文件与 SHA-256 在 [manifest.json](evidence/media/manifest.json) 中列出。

The installed 1.0.1 app completed these saves through the file picker. Redacted native events and hashes are linked above.

| 输出 / Output | 实际尺寸 / Actual dimensions | UTC 保存时间 / Saved at |
| --- | --- | --- |
| `Citrus Demo.jpg` | 3000 × 3751 | 2026-10-03T04:01:40Z |
| `Citrus Demo Cropped (2).jpg` | 1897 × 1739 | 2026-10-03T04:08:08Z |
| `Citrus Demo Cropped (2) BG.jpg` | 4941 × 2779 | 2026-10-03T04:09:10Z |

手柄拖动后的裁剪窗口显示 1896 × 1738，整数边界保存为 1897 × 1739；这一像素取整差异已列入验收清单。视频展示实际像素和实际文件，没有调整数字来掩盖差异。现有精确像素输入自动用例通过，属于不同操作路径。

The dragged selection displayed rounded fields of 1896 × 1738 and saved integer bounds of 1897 × 1739. This one-pixel difference is recorded in acceptance. The footage and export retain their actual values. The passing exact pixel-input automated case exercises a different path.

所有光标移动和转场为重演；视频内有中英说明。真实 Finder Shift / Shift+Option 未在此次演示中获得验收证据，仍待 Kris 物理操作复验。轻音效由本项目原创，AAC 48 kHz 双声道；竖屏解码音量峰值 −25.8 dBFS，没有削波。GitHub GIF 无声。

Cursor motion and transitions are recreated and labelled in both languages. Physical Finder Shift / Shift+Option remains pending Kris's retest. Sound cues are original, AAC 48 kHz stereo; the vertical decoded peak is −25.8 dBFS with no clipping. The README GIF is silent.

## 回执入口 / Receipts

[竖屏完整检查 / Vertical check](evidence/media/vertical-check.json) · [横屏完整检查 / Horizontal check](evidence/media/horizontal-check.json) · [封面完整检查 / Cover check](evidence/media/cover-check.json) · [文件规格与哈希 / Manifest](evidence/media/manifest.json)

GitHub 文档、文件链接和发布文件的独立检查见 [发布资料核验](evidence/media/publication-check.json)。GitHub 仓库保持私有，社交媒体发布尚未执行。

Documentation links and publication files are independently checked in the linked publication receipt. The GitHub repository remains private; social posting has not been performed.
