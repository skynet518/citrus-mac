# 橘子 / Citrus for Mac

一个在本机处理文件的 macOS 菜单栏应用：拖动文件打开圆形菜单，转换格式，裁剪图片，添加背景，编辑和标注图片。

**当前状态：私有验收版本 1.0.1。** 自动功能检查 92 项通过；1.0.0 的 Finder Shift 拖拽由使用者报告“圆盘没有出现”。1.0.1 已补充新拖拽剪贴板检测、旧文件路径格式兼容和诊断记录，真实组合键拖拽需要重新验收。完整的产品验收尚未通过。

本项目是独立实现，交互参考使用者提供的 Tangerine 演示。与 Tangerine 无隶属关系，也未复制其源码、商标或界面素材。当前版本没有宣称复现原产品的全部转换类型、全部工具或所有未展示的状态。

## 使用

1. 将构建生成的 `橘子.app` 放入“应用程序”，双击启动。
2. 收起使用说明窗口，按住 **Shift** 在 Finder 中拖动支持的文件，移入目标格式扇区后松手。
3. 拖动图片时同时按住 **Shift + Option**，切换到工具菜单。可选择 Crop、Add BG 等工具。
4. 也可以点击菜单栏的白色橘子图标，选择“选择文件…”；按 Tab 可切换工具，Esc 可关闭菜单。
5. 输出保存在原文件旁边，重名时自动添加序号，原文件保留。

“体验示例”会创建应用自己的样例文件，并打开原生拖拽演练窗口。演练中的拖拽与 Finder 的全局组合键拖拽分别验收。

## 已实现的范围

- 图片转换：JPG、PNG、WebP、HEIC、TIFF、AVIF、BMP、PDF、DOCX。
- 图片工具：压缩、元数据、调色、标注、背景、裁剪、遮挡。包含裁剪手柄、比例与像素输入；背景渐变、纯色、照片、留白、圆角和阴影。
- PDF：按页转换图片、拆分、合并、文字提取；扫描页文字提取使用系统 OCR。
- 使用本机 FFmpeg 的音视频转换与部分编辑，以及字幕和归档文件操作。完整输入输出组合尚未全部验证。

PNG 压缩会减少颜色，是有损处理。PDF 压缩会栅格化页面，不保留可搜索文字。图片转 DOCX 会嵌入图片；PDF 转 DOCX 不保证复杂版式。GIF 图片编辑使用首帧。RAR 创建不在当前范围内。

## 构建与测试

需要 macOS、Swift 6 工具链和 Apple Command Line Tools。项目声明最低 macOS 14；当前本地验证环境是 Apple Silicon、macOS 26.5.1、Swift 6.3.3，其他 Mac 系统版本与 Intel 真机没有完成验收。

```sh
./scripts/build-app.sh
./scripts/test.sh
```

应用输出到 `dist/橘子.app`。首次构建会通过 Swift Package Manager 获取固定版本的 Swift-WebP 和其依赖。

音视频处理需要自行安装 FFmpeg，应用不会下载或捆绑 FFmpeg。程序查找 `/opt/homebrew/bin/ffmpeg` 或 `/usr/local/bin/ffmpeg`。测试脚本要求 FFmpeg 与 ffprobe 可用，并拒绝把跳过的检查算作通过。

完整结果与验收边界见 [测试报告](docs/TESTING.md)，已知问题见 [验收清单](docs/ACCEPTANCE.md)。GitHub Actions 配置负责构建和自动检查；配置文件本身不代表云端测试通过。

## 本地数据

文件处理代码不包含上传文件或调用在线模型的操作。示例保存在用户的 Application Support/CitrusLocal 目录。诊断记录保存在用户的 Library/Logs/CitrusLocal/events.jsonl，其中输出事件可能包含本地文件路径；不自动上报。

本地应用包采用临时签名，未完成 Apple Developer ID 签名和公证。它目前用于私有验收。Windows 和 Linux 版本已延期，仓库只包含 Mac 实现。

## 许可证与致谢

独立实现使用 MIT 许可证。第三方组件保留各自许可，见 [第三方声明](THIRD_PARTY_NOTICES.md)。
