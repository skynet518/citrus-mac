# 可编辑演示源文件 / Editable demo source

[素材目录 / Media](../MEDIA.md) · [检查结果 / Validation](../MEDIA_VALIDATION.md)

这里保存已交付视频的 HTML、原生截图、实际输出图和原创轻音效。所有动画均由固定时间线驱动；无需应用、屏幕录制或原参考视频即可重新导出。它是演示制作工程，应用实现位于仓库的 `native/`。

This directory contains delivered composition HTML, native screenshots, actual exports, and original sound cues. Deterministic timelines allow rerendering without running the app, screen-recording the desktop, or using the reference clip. The app implementation lives in the repository's `native/` directory.

| 文件 / File | 用途 / Purpose |
| --- | --- |
| `index.html` | 1080 × 1920 竖屏视频 / vertical video |
| `horizontal.html` | 1920 × 1080 横屏视频 / horizontal video |
| `cover-square.html` | 1080 × 1080 方形封面 / square cover |
| `DESIGN.md` | 版式、节奏、素材和证据约束 / design and evidence decisions |
| `make-sound.py` | 重建原创轻音效 / regenerate original cues |
| `assets/` | GSAP、音效与专门审核的示例图 / GSAP, sound, approved demo imagery |
| `tools/audit-frames.mjs` | 每帧时间点的文字和素材来源检查 / frame-timestamp provenance audit |

## 重新导出 / Rerender

本次制作使用 Node.js 22.16、HyperFrames 0.8.114、GSAP 3.14.2 与本机 FFmpeg 7.1.1。中文使用 macOS 本机 PingFang SC，英文使用本机 Georgia；没有分发 Apple 字体文件。其他系统需要自备允许使用的中文字库并重新检查版面，跨系统同像素输出尚未验证。

The delivered render used Node.js 22.16, HyperFrames 0.8.114, GSAP 3.14.2, and local FFmpeg 7.1.1. Fonts are local macOS PingFang SC and Georgia; Apple font files are not redistributed. Other systems require an appropriately licensed Chinese font and renewed layout checks; identical cross-platform pixels have not been verified.

在此目录运行 / Run in this directory:

```sh
npm ci
npm run check -- --samples 15
npx --yes hyperframes@0.8.114 render --composition index.html --output renders/vertical.mp4 --quality high --fps 30 --workers 1 --no-best-effort
npx --yes hyperframes@0.8.114 render --composition horizontal.html --output renders/horizontal.mp4 --quality high --fps 30 --workers 1 --no-best-effort
```

渲染器需要可用的 Chromium 与 FFmpeg。若自动浏览器准备无法完成，可设置 `HYPERFRAMES_BROWSER_PATH` 为自己机器上兼容的 Chromium 可执行文件路径；源文件不包含制作机器的路径。竖屏、横屏和封面在交付前作为独立工程分别检查，结果见 `../evidence/media/`。

Rendering needs Chromium and FFmpeg. If automatic browser setup cannot complete, point `HYPERFRAMES_BROWSER_PATH` at a compatible local Chromium executable. No production-machine path is stored here. Portrait, landscape, and cover were checked as separate projects before delivery; reports are in `../evidence/media/`.

```sh
python3 make-sound.py
node tools/audit-frames.mjs . 1080 1920
```

第二个命令针对入口 `index.html`；横屏来源检查在制作时以独立入口执行。该检查读取各时间点的页面文字和图片引用，不对编码后 MP4 的每帧像素做 OCR。

The second command audits `index.html`; landscape provenance was checked using a separate entry project during production. It inspects page text and image references at each timestamp, rather than OCR-scanning every encoded MP4 frame.

## 许可 / Licenses

原创界面截图、演示插画、时间线及音效按仓库 MIT 许可证提供。`assets/gsap.min.js` 为 GSAP 3.14.2，遵循 [GSAP Standard License](https://gsap.com/community/standard-license/)；保留其原有版权头，不将它重新标为 MIT。HyperFrames 是制作工具，不是原生橘子应用的运行依赖。见 [第三方声明](../../THIRD_PARTY_NOTICES.md)。

Original captures, demo artwork, timelines, and cues use the repository's MIT license. GSAP 3.14.2 in `assets/gsap.min.js` retains the [GSAP Standard License](https://gsap.com/community/standard-license/) and its copyright header. HyperFrames is a production tool, separate from the native app's runtime dependencies. See [third-party notices](../../THIRD_PARTY_NOTICES.md).
