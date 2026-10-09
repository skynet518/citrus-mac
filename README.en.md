# Citrus for Mac / 橘子

[中文](README.md) · [English](README.en.md) · [中文图文教程](docs/GUIDE.zh-CN.md) · [English illustrated guide](docs/GUIDE.en.md)

Convert files, crop images, and add backgrounds on your Mac. Citrus lives in the menu bar and brings common actions into a radial menu.

[![Citrus actual UI demo: PDF to JPG, Crop, Add BG](docs/media/citrus-demo-preview.gif)](docs/media/citrus-demo-horizontal-zh-en.mp4)

**[▶ Watch the full 28-second HD demo with light sound cues and Chinese/English captions](docs/media/citrus-demo-horizontal-zh-en.mp4)** · [Vertical version](docs/media/citrus-demo-vertical-zh-en.mp4) · [Covers and editable media](docs/MEDIA.md)

The demo uses actual Citrus 1.0.1 screens and exported files. Cursor motion is recreated, and the workflow starts with the file picker. Only purpose-made demo files appear.

**MIT open-source UI preview: 1.1.0.** This branch adds a desktop citrus button, clickable Format/Tools mode selection, and native glass UI. The installed local app recorded **108 PASS / 0 FAIL / 0 SKIP**, including 16 new checks; see [all cases and native screenshots](docs/UI_REVIEW_1_1.md). Physical Finder drops, button movement, and desktop-layer behavior remain pending acceptance. The video and older illustrated guides below show **1.0.1**, retained on [main](https://github.com/skynet518/citrus-mac/tree/main). This source preview does not claim full product acceptance.

![1.1.0 welcome UI](docs/review-images-1.1.0/welcome-dark.png)

## Try it: PDF → JPG → Crop → Add BG

1. Open `橘子.app` from Applications. Click **选择文件…** (Choose files) in the welcome window, or use the white citrus menu bar icon.
2. Select [Citrus Demo.pdf](docs/demo-files/Citrus%20Demo.pdf), then click **JPG** on the wheel. The output is saved beside the source.
3. Select the new JPG, click **工具** (Tools) in the center, or press **Tab**, then click **Crop**. Drag the handles and click **Apply**.
4. Select the cropped copy, click **工具** (Tools), or press **Tab**, then click **Add BG**. Adjust the background, padding, corners, shadow, and ratio; click **Save with Background**.

The **[English illustrated guide](docs/GUIDE.en.md)** shows every screen, control, and output. The source is preserved; existing outputs receive numbered filenames. `Esc` closes the wheel. Arrow keys and Enter can also select an action.

## Build and install

The repository currently provides source and a verified build workflow. Building 1.1.0 requires a Swift 6 toolchain and Xcode or Apple Command Line Tools with the macOS 26 SDK.

```sh
./scripts/build-app.sh
./scripts/test.sh
```

Move `dist/橘子.app` to Applications and open it. Citrus stays in the top menu bar; after closing the welcome window, use its white citrus icon to reopen instructions or choose files. The current app uses ad-hoc signing and has not received Apple Developer ID signing or notarization.

The declared minimum is macOS 14. The tested local environment is Apple Silicon, macOS 26.5.1, Swift 6.3.3; CI used macOS 26 ARM64. Intel Macs and other macOS releases have not completed physical acceptance. Windows and Linux work has been deferred.

Audio/video processing requires a separate local FFmpeg installation. Citrus does not download or bundle FFmpeg. It checks `/opt/homebrew/bin/ffmpeg` and `/usr/local/bin/ffmpeg`. The first build downloads pinned Swift-WebP dependencies through Swift Package Manager.

## Capabilities and limits

| Area | Implemented | Limits |
| --- | --- | --- |
| Image conversion | JPG, PNG, WebP, HEIC, TIFF, AVIF, BMP, PDF, DOCX | Output encodings are checked in the listed automated cases; the full input/output matrix is not accepted |
| Image tools | Compress, Metadata, Edit, Annotate, Add BG, Crop, Redact | PNG compression reduces colors; GIF editing uses the first frame |
| PDF | Export pages as images, split, merge, extract text, system OCR | Compression rasterizes pages and removes searchable text; PDF-to-DOCX does not preserve every complex layout |
| Documents and media | Images embedded in DOCX, subtitles, archives, local FFmpeg audio/video processing | Word/Pages rendering and all media editing combinations still need acceptance; RAR creation is outside the current scope |

The new entry is designed to open the wheel beside the desktop citrus button when a file is dragged onto it, then keep the wheel available after the drop. Settings provide floating or desktop-only placement. This flow still needs physical mouse acceptance; see the [pending checks](docs/UI_REVIEW_1_1.md). Legacy Shift-drag compatibility is optional and off by default.

## Tests and evidence

- [Current 1.1.0: all 108 results, UI checks, and pending acceptance](docs/UI_REVIEW_1_1.md)
- [Historical 1.0.1: 92 checks](docs/TESTING.en.md)
- [Historical 1.0.1 GitHub Actions run #37063085729](https://github.com/skynet518/citrus-mac/actions/runs/37063085729)
- [Installed-app receipt](docs/evidence/local-verification.json) · [Clean-build summary](docs/evidence/clean-build-summary.json) · [CI per-check receipt](docs/evidence/github-ci-verification.json)
- [Media validation report](docs/MEDIA_VALIDATION.md): layout, caption contrast, complete decoding, provenance, and privacy

Automated functionality, media validation, and physical desktop acceptance are recorded separately. The older demo is retained; current UI source and installed-build evidence are linked in the 1.1.0 review above.

## Local data and licensing

The file-processing code has no file-upload or online-model call. App-owned samples use the user's `Application Support/CitrusLocal` directory. Diagnostic events use `Library/Logs/CitrusLocal/events.jsonl`; output events can contain local paths, and logs are not sent automatically.

Citrus is an independent implementation inspired by a user-supplied Tangerine interaction demo. It is unaffiliated with Tangerine and does not copy its source, branding, or interface assets. This version does not claim complete parity with all of the original product's features or states.

Original code and media use [MIT](LICENSE). Third-party components and the demo animation library retain their own licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).
