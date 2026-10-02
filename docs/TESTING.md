# 橘子 1.0.1：Mac 补充测试与拖拽复验

日期：2026-10-03（Asia/Shanghai）。本地环境：Apple Silicon arm64、macOS 26.5.1、Swift 6.3.3。

## 当前结论

使用“应用程序”中安装后的程序执行，**92 项自动功能检查通过，0 失败，0 跳过**。这包括旧的 49 项以及新增的 43 项。另做一次“故意失败”探针，确认失败结果保留且程序返回非零退出；它不混入功能通过数。

用户对 1.0.0 的 Finder Shift 拖拽反馈是“圆盘没有出现”，因此核心真实桌面入口曾经验收失败。1.0.1 已改为鼠标监听加新拖拽剪贴板检测，并兼容旧文件路径格式。修复版本的真实 Shift / Shift+Option 拖拽仍等待复验，不能把自动检查全部通过写成产品验收全部通过。

安装程序：`橘子.app`；二进制 SHA-256：`c0805d3cef86df5409a07065084e2474fb2ba71b89defd048b16610db00c02f0`。

检查时间（UTC）：2026-10-02T20:43:13Z。原始回执：[`evidence/local-verification.json`](evidence/local-verification.json)。旧 49 项完整报告与附件继续保留。

## 本轮具体改动

- 新文件拖拽会话可在缺少全局拖动通知时被检测；旧拖拽数据、编辑器内部拖动与已取消会话不会重新触发。
- 文件拖拽读取支持标准 URL 与旧文件路径列表，过滤不支持类型和重复项。
- 测试结果逐项原子保存；失败记录真实 FAIL 数和错误，不再只有跑到结尾才能看到回执。
- 图片转换检查实际文件编码；媒体结果检查真实编码并完整解码；DOCX 检查 XML 和内嵌图片。
- 压缩不会因为勾选缩尺寸就接受反而更大的图片输出。

## 全部 92 项自动用例

表中“断言”是具体预期，“实测”来自本轮结果。对原有未记录文字细节的项目，PASS 表示源码断言通过，不能解释成扩大后的功能承诺。新增状态模型检查不代替真实系统拖拽。

| ID | 用例 | 源码标识 | 断言 | 实测 | 结果 |
| --- | --- | --- | --- | --- | --- |
| MAC-01 | PNG 转 JPG | convert_jpg | 有效文件，可解码，尺寸 240×320，非空；文件类型必须与目标编码一致 | public.jpeg, 240×320, 2815 bytes | PASS |
| MAC-02 | PNG 转 PNG | convert_png | 有效文件，可解码，尺寸 240×320，非空；文件类型必须与目标编码一致 | public.png, 240×320, 2422 bytes | PASS |
| MAC-03 | PNG 转 WEBP | convert_webp | 有效文件，可解码，尺寸 240×320，非空；文件类型必须与目标编码一致 | org.webmproject.webp, 240×320, 298 bytes | PASS |
| MAC-04 | PNG 转 HEIC | convert_heic | 有效文件，可解码，尺寸 240×320，非空；文件类型必须与目标编码一致 | public.heic, 240×320, 602 bytes | PASS |
| MAC-05 | PNG 转 TIFF | convert_tiff | 有效文件，可解码，尺寸 240×320，非空；文件类型必须与目标编码一致 | public.tiff, 240×320, 310590 bytes | PASS |
| MAC-06 | PNG 转 AVIF | convert_avif | 有效文件，可解码，尺寸 240×320，非空；文件类型必须与目标编码一致 | public.avif, 240×320, 490 bytes | PASS |
| MAC-07 | PNG 转 BMP | convert_bmp | 有效文件，可解码，尺寸 240×320，非空；文件类型必须与目标编码一致 | com.microsoft.bmp, 240×320, 307338 bytes | PASS |
| MAC-08 | PNG 转 PDF | convert_pdf | 以 %PDF 开头，PDFKit 读取为 1 页 | 已满足上述断言（详见测试源码） | PASS |
| MAC-09 | PNG 转 DOCX | convert_docx | ZIP 内包含 word/document.xml 和 word/media/image0.png | 已满足上述断言（详见测试源码） | PASS |
| MAC-10 | 转换后原文件保留 | source_unchanged | 前后文件字节完全相同 | 已满足上述断言（详见测试源码） | PASS |
| MAC-11 | 同名输出保护 | collision_avoids_overwrite | 两个输出路径不同，不覆盖已存在结果 | 已满足上述断言（详见测试源码） | PASS |
| MAC-12 | 按原图尺寸裁剪 | crop_full_resolution | 保存后重新解码为 144×160 | 已满足上述断言（详见测试源码） | PASS |
| MAC-13 | 背景边距 | background_padding | 输出画布为 224×240 | 已满足上述断言（详见测试源码） | PASS |
| MAC-14 | 16:9 背景比例 | background_aspect_ratio | 输出宽高比与 16:9 的差小于 0.01 | 已满足上述断言（详见测试源码） | PASS |
| MAC-15 | 预览与导出比例一致 | preview_matches_export_ratio | 预览和导出宽高比之差小于 0.02 | 已满足上述断言（详见测试源码） | PASS |
| MAC-16 | 遮盖写入像素 | redaction_is_baked_into_pixels | 取样 RGB 三通道均小于 5 | [0, 0, 0, 255] | PASS |
| MAC-17 | 旋转尺寸 | rotate_dimensions | 输出尺寸变为 320×240 | 已满足上述断言（详见测试源码） | PASS |
| MAC-18 | 饱和度归零 | edit_saturation | RGB 相邻通道之差均小于 3 | 已满足上述断言（详见测试源码） | PASS |
| MAC-19 | 多页 PDF 全部导出 | pdf_all_pages | 返回两张图片 | 已满足上述断言（详见测试源码） | PASS |
| MAC-20 | PDF 以 300 DPI 栅格化 | pdf_300dpi | 导出图片为 300×400 像素 | 已满足上述断言（详见测试源码） | PASS |
| MAC-21 | 拆分再合并 | pdf_split_merge | 拆分为两个文件，合并结果为两页 | 已满足上述断言（详见测试源码） | PASS |
| MAC-22 | 第 1 个扇区命中 | radial_sector_0 | 命中索引 0；此项为坐标计算检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-23 | 第 2 个扇区命中 | radial_sector_1 | 命中索引 1；此项为坐标计算检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-24 | 第 3 个扇区命中 | radial_sector_2 | 命中索引 2；此项为坐标计算检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-25 | 第 4 个扇区命中 | radial_sector_3 | 命中索引 3；此项为坐标计算检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-26 | 第 5 个扇区命中 | radial_sector_4 | 命中索引 4；此项为坐标计算检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-27 | 第 6 个扇区命中 | radial_sector_5 | 命中索引 5；此项为坐标计算检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-28 | 第 7 个扇区命中 | radial_sector_6 | 命中索引 6；此项为坐标计算检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-29 | 第 8 个扇区命中 | radial_sector_7 | 命中索引 7；此项为坐标计算检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-30 | 圆盘中心不执行 | radial_center_cancels | 不选中任何扇区 | 已满足上述断言（详见测试源码） | PASS |
| MAC-31 | 圆盘外部不执行 | radial_outside_cancels | 不选中任何扇区 | 已满足上述断言（详见测试源码） | PASS |
| MAC-32 | 屏幕边缘定位 | radial_screen_edge_clamp | 整个菜单框位于测试屏幕内；未测试真实多屏 | 已满足上述断言（详见测试源码） | PASS |
| MAC-33 | 隐藏当前格式 | current_format_excluded | 目录不包含 PNG | 已满足上述断言（详见测试源码） | PASS |
| MAC-34 | 七个图片工具 | image_tool_catalog | 工具数量为 7；此断言未逐个执行工具界面 | 已满足上述断言（详见测试源码） | PASS |
| MAC-35 | SRT／VTT 时间与文字 | subtitle_conversion | VTT 以 WEBVTT 开头，时间变为 00:00:01.500，纯文本含“你好” | 已满足上述断言（详见测试源码） | PASS |
| MAC-36 | 移除位置信息 | metadata_location_removed | 导出 JPEG 回读不含 GPS 字典 | 已满足上述断言（详见测试源码） | PASS |
| MAC-37 | 作者写入后回读 | metadata_author_saved | 导出 JPEG 的 IPTC Byline 回读为 Kris | 已满足上述断言（详见测试源码） | PASS |
| MAC-38 | 描述写入后回读 | metadata_caption_saved | IPTC CaptionAbstract 回读为 Local test | 已满足上述断言（详见测试源码） | PASS |
| MAC-39 | 元数据编辑保留原图 | metadata_original_preserved | 原文件字节完全相同 | 已满足上述断言（详见测试源码） | PASS |
| MAC-40 | 压缩后体积减小 | compression_smaller | 结果字节数小于原文件；此项同时使用缩小尺寸 | 已满足上述断言（详见测试源码） | PASS |
| MAC-41 | 压缩时最长边限制 | compression_resize | 重新解码后最长边等于 128 | 已满足上述断言（详见测试源码） | PASS |
| MAC-42 | 批量部分失败保留成功项 | partial_batch_keeps_successes | 返回 1 个成功结果、1 个错误，成功文件仍存在 | 已满足上述断言（详见测试源码） | PASS |
| MAC-43 | 长文本分页 | text_pagination | 生成页面数量大于 1；未逐页核对末尾全文 | 已满足上述断言（详见测试源码） | PASS |
| MAC-44 | ZIP 解压与内容回读 | archive_extract | 解压后的 note.txt 内容完全一致 | 已满足上述断言（详见测试源码） | PASS |
| MAC-45 | ZIP 转 TAR | archive_convert | 系统 tar 列表中包含 note.txt | 已满足上述断言（详见测试源码） | PASS |
| MAC-46 | WAV 转 MP3 | audio_real_encode | 生成 MP3，文件大于 100 字节；此原断言未做完整播放检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-47 | MP4 转 WebM | video_real_encode | 生成 WebM，文件大于 100 字节；此原断言未做全帧解码检查 | 已满足上述断言（详见测试源码） | PASS |
| MAC-48 | 视频移除音轨 | video_mute_removes_audio | ffprobe 查询音频流为空 | 已满足上述断言（详见测试源码） | PASS |
| MAC-49 | 视频裁切时间 | media_trim_duration | ffprobe 时长与 1 秒之差小于 0.1 秒 | 已满足上述断言（详见测试源码） | PASS |
| MAC-50 | 忽略上次拖拽留下的文件 | drag_stale_pasteboard_ignored | Old file drag + held mouse does not activate. | Old file drag + held mouse does not activate. | PASS |
| MAC-51 | 缺少拖动通知时仍能识别新会话 | drag_fresh_pasteboard_without_event | Fresh file drag activates without an NSEvent callback; physical Shift remains a separate manual check. | Fresh file drag activates without an NSEvent callback; physical Shift remains a separate manual check. | PASS |
| MAC-52 | 编辑器内部拖动不触发全局菜单 | drag_editor_mouse_ignored | Crop, paint and window drags stay outside the desktop entry. | Crop, paint and window drags stay outside the desktop entry. | PASS |
| MAC-53 | 取消或完成后本次会话保持关闭 | drag_consumed_session_stays_closed | Esc/drop consumes the session until button release. | Esc/drop consumes the session until button release. | PASS |
| MAC-54 | 松手后下一次新拖拽可以再次激活 | drag_next_session_rearms | Release resets the baseline; a new file drag re-arms. | Release resets the baseline; a new file drag re-arms. | PASS |
| MAC-55 | 读取标准文件 URL 拖拽数据 | drag_modern_file_url_read | Private pasteboard with public.file-url. | Private pasteboard with public.file-url. | PASS |
| MAC-56 | 读取旧文件路径格式、去重并过滤 | drag_legacy_file_paths_read | NSFilenamesPboardType works, duplicates and unsupported extensions are filtered. | NSFilenamesPboardType works, duplicates and unsupported extensions are filtered. | PASS |
| MAC-57 | PNG 透明像素与半透明红色保存后读回 | transparency_png | Corner [0, 0, 0, 0]; half-transparent red center [128, 19, 0, 128], premultiplied RGBA. | Corner [0, 0, 0, 0]; half-transparent red center [128, 19, 0, 128], premultiplied RGBA. | PASS |
| MAC-58 | WEBP 透明像素与半透明红色保存后读回 | transparency_webp | Corner [0, 0, 0, 0]; half-transparent red center [128, 19, 0, 128], premultiplied RGBA. | Corner [0, 0, 0, 0]; half-transparent red center [128, 19, 0, 128], premultiplied RGBA. | PASS |
| MAC-59 | 透明图片转 JPG 后透明区填白 | jpeg_transparency_white | Transparent corner becomes white: [255, 255, 255, 255]. | Transparent corner becomes white: [255, 255, 255, 255]. | PASS |
| MAC-60 | 按照片方向标记旋转像素 | exif_orientation_applied | EXIF orientation 6 loads as 320×240. | EXIF orientation 6 loads as 320×240. | PASS |
| MAC-61 | 导出后不重复旋转 | exif_orientation_not_applied_twice | Export has normalized pixels and no stale orientation tag. | Export has normalized pixels and no stale orientation tag. | PASS |
| MAC-62 | 拒绝损坏图片 | corrupt_image_rejected | Malformed PNG is rejected. | Malformed PNG is rejected. | PASS |
| MAC-63 | 超出宽度上限时先拒绝分配 | oversized_canvas_rejected | Width above 24000 is rejected before allocation. | Width above 24000 is rejected before allocation. | PASS |
| MAC-64 | 拒绝完全位于图像外的裁剪框 | outside_crop_rejected | Crop completely outside the image is rejected. | Crop completely outside the image is rejected. | PASS |
| MAC-65 | 只移除定位时保留作者 | gps_only_removal_keeps_author | Removing only location preserves the existing author. | Removing only location preserves the existing author. | PASS |
| MAC-66 | 关闭移除定位时保留定位 | gps_preserved_when_requested | Location remains only when removal is disabled. | Location remains only when removal is disabled. | PASS |
| MAC-67 | 中文作者与描述写入 PNG 后读回 | png_unicode_metadata | PNG author and description survive Unicode round-trip. | PNG author and description survive Unicode round-trip. | PASS |
| MAC-68 | 不缩尺寸的 JPG 压缩 | jpeg_compression_preserves_dimensions | JPEG compression without resizing remains 256×256 and shrinks bytes. | JPEG compression without resizing remains 256×256 and shrinks bytes. | PASS |
| MAC-69 | 不缩尺寸的 PNG 减色压缩 | png_compression_shrinks | PNG uses lossy color quantization; size stays 256×256. | PNG uses lossy color quantization; size stays 256×256. | PASS |
| MAC-70 | PDF 压缩保留页数和物理页面尺寸 | pdf_compression_page_geometry | Raster compression shrinks bytes and preserves page dimensions within 1 pt; searchable text is not retained. | Raster compression shrinks bytes and preserves page dimensions within 1 pt; searchable text is not retained. | PASS |
| MAC-71 | 批量全部失败时明确列出错误 | batch_all_failures_reported | Two missing inputs produce zero successes and two explicit errors. | Two missing inputs produce zero successes and two explicit errors. | PASS |
| MAC-72 | 自定义纯色背景写入最终图片 | background_custom_color | Custom green background corner: [0, 255, 0, 255]. | Custom green background corner: [0, 255, 0, 255]. | PASS |
| MAC-73 | 圆角区域露出背景 | background_rounded_corner | Rounded image corner reveals the background: [0, 255, 0, 255]. | Rounded image corner reveals the background: [0, 255, 0, 255]. | PASS |
| MAC-74 | 照片背景写入最终图片 | background_photo_rendered | Photo background is composited into the exported pixels. | Photo background is composited into the exported pixels. | PASS |
| MAC-75 | 画笔标注烘焙进导出像素 | annotation_pen_export | Decoded export has 5318 changed color bytes, with actual raster annotation. | Decoded export has 5318 changed color bytes, with actual raster annotation. | PASS |
| MAC-76 | 矩形标注烘焙进导出像素 | annotation_rectangle_export | Decoded export has 12816 changed color bytes, with actual raster annotation. | Decoded export has 12816 changed color bytes, with actual raster annotation. | PASS |
| MAC-77 | 箭头标注烘焙进导出像素 | annotation_arrow_export | Decoded export has 8062 changed color bytes, with actual raster annotation. | Decoded export has 8062 changed color bytes, with actual raster annotation. | PASS |
| MAC-78 | 文字标注烘焙进导出像素 | annotation_text_export | Decoded export has 6522 changed color bytes, with actual raster annotation. | Decoded export has 6522 changed color bytes, with actual raster annotation. | PASS |
| MAC-79 | 先黑块遮挡再模糊不露出原内容 | redaction_then_blur_stays_hidden | Later blur uses the already redacted pixels; center [0, 0, 0, 255]. | Later blur uses the already redacted pixels; center [0, 0, 0, 255]. | PASS |
| MAC-80 | 先黑块遮挡再像素化不露出原内容 | redaction_then_pixelate_stays_hidden | Later pixelate uses the already redacted pixels; center [0, 0, 0, 255]. | Later pixelate uses the already redacted pixels; center [0, 0, 0, 255]. | PASS |
| MAC-81 | 裁剪比例影响真实输出尺寸 | crop_ratio_model | Selecting 1:1 produces 240×240 from 240×320. | Selecting 1:1 produces 240×240 from 240×320. | PASS |
| MAC-82 | 裁剪像素输入影响真实输出尺寸 | crop_pixel_dimensions | Pixel fields drive actual 120×90 output. | Pixel fields drive actual 120×90 output. | PASS |
| MAC-83 | 重置恢复原始裁剪状态和像素字段 | editor_reset_restores_original | Reset restores crop, pixel fields and annotation state. | Reset restores crop, pixel fields and annotation state. | PASS |
| MAC-84 | Option 状态切换到七个图片工具 | option_switches_seven_tools | Option changes the JPEG menu to seven tools. | Option changes the JPEG menu to seven tools. | PASS |
| MAC-85 | 释放 Option 状态切换回八个图片格式 | option_release_restores_formats | Releasing Option restores eight JPEG format targets. | Releasing Option restores eight JPEG format targets. | PASS |
| MAC-86 | 混合文件只展示共有操作 | mixed_batch_common_actions | PNG + PDF exposes only their common conversions and tools; format order follows the first file. | PNG + PDF exposes only their common conversions and tools; format order follows the first file. | PASS |
| MAC-87 | DOCX 四个关键 XML 部分均可解析 | docx_xml_parts_parse | Content types, package relationships, document and image relationships all parse as XML. | Content types, package relationships, document and image relationships all parse as XML. | PASS |
| MAC-88 | DOCX 内嵌图片可解码且尺寸正确 | docx_embedded_image_decodes | DOCX contains a real, decodable 240×320 image. Office rendering remains manual. | DOCX contains a real, decodable 240×320 image. Office rendering remains manual. | PASS |
| MAC-89 | 末页文字经 OCR 证明没有被截断 | text_last_page_contains_tail | OCR of the last rendered page confirms the ending text was not truncated. | OCR of the last rendered page confirms the ending text was not truncated. | PASS |
| MAC-90 | 解压前拒绝包含符号链接的归档 | archive_symlink_rejected | ZIP containing a symbolic link is rejected before extraction. | ZIP containing a symbolic link is rejected before extraction. | PASS |
| MAC-91 | MP3 编码正确且全文件可解码 | audio_stream_fully_decodes | Expected mp3 codec and complete FFmpeg decode without errors. | Expected mp3 codec and complete FFmpeg decode without errors. | PASS |
| MAC-92 | WebM 编码正确且全文件可解码 | video_stream_fully_decodes | Expected vp9 codec and complete FFmpeg decode without errors. | Expected vp9 codec and complete FFmpeg decode without errors. | PASS |

## 失败记录与结果保存审查

第一轮新增检查记录为 85 PASS / 1 FAIL。失败项是混合文件菜单检查：测试错误地固定了共有格式的顺序，而程序保留首个文件的顺序。更正为比较共有格式集合，并保留工具顺序检查；修正后完整检查通过。第一次失败回执保留，没有删除或改成 PASS。

故意失败探针独立记录为 0 PASS / 1 FAIL，退出码 1；探针审查结论 PASS，证明错误路径会留下结果。该 FAIL 是刻意触发的测试机制检查，不是产品功能失败。

历史 1.0.0 结果（35 项、49 项等）仍在原来的完整材料中。两个早期没有最终回执的运行继续标记 UNKNOWN，不能计入通过记录。

## 真实界面与待验收项

| 项目 | 当前结果 | 判断边界 |
| --- | --- | --- |
| 新版安装在“应用程序”，原生启动 | PASS | 实际文件、版本、签名核验、原生窗口 |
| 白色橘子图标 | 已绘制并核验 | 真实菜单栏的主观辨识度仍可反馈 |
| PDF 拖入格式、裁剪手柄、箭头标注、背景调整并导出 | 历史实际界面 PASS | 来自应用自身原生拖拽演练和圆盘点击；不是 Finder 全局组合键证明 |
| 1.0.0 Finder Shift 拖动 | FAIL，用户报告 | 圆盘没有出现 |
| 1.0.1 Finder Shift 拖动 | PENDING | 已安装修复，等重新操作和入口日志 |
| 1.0.1 Shift+Option 工具切换 | PENDING | 自动状态模型 PASS 不代替真实组合键 |
| 多屏、Spaces、全屏 | NOT_VERIFIED | 自动屏幕边界检查仅验证计算 |
| Intel、其他 macOS 版本 | NOT_VERIFIED | 最低系统声明不等于测试过 |
| Word/Pages 打开 DOCX | NOT_VERIFIED | XML 可解析、图片可解码不等于文档渲染验收 |
| 全部输入格式与媒体编辑组合 | NOT_VERIFIED | 已覆盖用例见上表，未覆盖的组合不算通过 |
| Apple Developer ID 签名和公证 | 未完成 | 目前是本地临时签名 |
| GitHub 公开发布 | 未执行 | 用户确认先建私有仓库，验收后再公开 |

## 复验操作

在 Finder 中按住 Shift 拖动 PDF，持续移动约一秒；圆盘出现后移入 JPG 扇区松手。确认输出后，按住 Shift+Option 拖动 JPG，检查是否切换到七个工具。再执行 Crop → Apply → Add BG → Save，并检查源文件保留。取消、中心和圆盘外松手应没有输出。

## 独立发布目录验证

源码复制到独立目录后，从零构建，92 项功能检查通过，0 失败，0 跳过；失败回执探针通过。该构建的 SHA-256 为 `3d9d439a533e58a67057d994be647e9dadda873a41cd7bae3c50e8c01570aaff`，因构建路径不同，与本地安装构建的哈希分列记录。详见 [`clean-build-summary.json`](evidence/clean-build-summary.json)。

GitHub Actions 使用官方列出的 macOS 26 ARM64 执行环境：[runner-images](https://github.com/actions/runner-images)。真实桌面验收仍单独记录，云端自动检查结果以实际运行回执为准。

## GitHub 云端实际结果

[Mac verification 运行 #37063085729](https://github.com/skynet518/citrus-mac/actions/runs/37063085729) 已成功完成，实际产物下载后再次核对：92 PASS / 0 FAIL / 0 SKIP，故意失败回执探针审查 PASS，应用打包成功。测试的源码提交为 `b0d6d5f964310a49aee2df6e72409e32579023d3`。

云端构建的二进制 SHA-256 为 `63f94082eef51b8a6b14ba09215a91f20dfeaeca3581b53faa9beb2e9c7b5dc2`。这是云端功能检查和打包证据；没有模拟或验证真实 Finder Shift / Shift+Option 操作。之后补充本节的提交仅更新文档与结果，不改变受测源码。
