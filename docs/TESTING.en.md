# Citrus 1.0.1: all 92 Mac checks

[中文](TESTING.md) · [Home](../README.en.md) · [Acceptance](ACCEPTANCE.en.md)

Recorded on 2026-10-03 (Asia/Shanghai). The installed local app ran on Apple Silicon arm64, macOS 26.5.1, Swift 6.3.3 and recorded **92 PASS / 0 FAIL / 0 SKIP**: the original 49 checks plus 43 added checks. A clean source build and the actual macOS 26 ARM64 GitHub run also recorded 92 passes. The intentional failure-receipt probe is separate from the functional pass count.

Finder Shift-drag in 1.0.0 failed by user report: the wheel did not appear. Version 1.0.1 adds fresh-drag pasteboard polling, legacy file-path support, filtering, and diagnostics. Physical Shift / Shift+Option retesting is **PENDING**. Automated model results do not establish product acceptance.

Installed binary SHA-256: `c0805d3cef86df5409a07065084e2474fb2ba71b89defd048b16610db00c02f0`.

Local check timestamp: `2026-10-02T20:43:13Z`. [Installed-app receipt](evidence/local-verification.json) · [Case list](evidence/test-cases.json)

## Assertions and observations

For original checks without detailed recorded observations, PASS means the source assertion succeeded; it does not extend the capability claim. The names below are exact source identifiers for traceability. Cases 50 onward include their recorded English assertions. Mixed-batch ordering follows the first file; the corrected assertion compares shared formats as a set.

| ID | Source check | Assertion | Observation | Result |
| --- | --- | --- | --- | --- |
| MAC-01 | convert_jpg | A nonempty, decodable 240×320 JPEG; detected encoding must match the target. | public.jpeg, 240×320, 2815 bytes | PASS |
| MAC-02 | convert_png | A nonempty, decodable 240×320 PNG; detected encoding must match the target. | public.png, 240×320, 2422 bytes | PASS |
| MAC-03 | convert_webp | A nonempty, decodable 240×320 WebP; detected encoding must match the target. | org.webmproject.webp, 240×320, 298 bytes | PASS |
| MAC-04 | convert_heic | A nonempty, decodable 240×320 HEIC; detected encoding must match the target. | public.heic, 240×320, 602 bytes | PASS |
| MAC-05 | convert_tiff | A nonempty, decodable 240×320 TIFF; detected encoding must match the target. | public.tiff, 240×320, 310590 bytes | PASS |
| MAC-06 | convert_avif | A nonempty, decodable 240×320 AVIF; detected encoding must match the target. | public.avif, 240×320, 490 bytes | PASS |
| MAC-07 | convert_bmp | A nonempty, decodable 240×320 BMP; detected encoding must match the target. | com.microsoft.bmp, 240×320, 307338 bytes | PASS |
| MAC-08 | convert_pdf | Output starts with %PDF and PDFKit reads one page. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-09 | convert_docx | DOCX ZIP contains word/document.xml and word/media/image0.png. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-10 | source_unchanged | Source bytes are identical before and after conversion. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-11 | collision_avoids_overwrite | Two outputs have different paths and no existing result is overwritten. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-12 | crop_full_resolution | Saved crop decodes as 144×160 pixels. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-13 | background_padding | Output canvas is 224×240 pixels. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-14 | background_aspect_ratio | Export ratio differs from 16:9 by less than 0.01. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-15 | preview_matches_export_ratio | Preview and export ratios differ by less than 0.02. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-16 | redaction_is_baked_into_pixels | Sampled redaction RGB channels are each less than 5. | [0, 0, 0, 255] | PASS |
| MAC-17 | rotate_dimensions | Rotated image dimensions become 320×240. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-18 | edit_saturation | Adjacent RGB channel differences are each less than 3. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-19 | pdf_all_pages | Two-page PDF returns two images. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-20 | pdf_300dpi | 300-DPI rasterization returns a 300×400 image. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-21 | pdf_split_merge | Split creates two files; merging them produces a two-page PDF. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-22 | radial_sector_0 | Coordinate model selects sector index 0; this is a geometry check. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-23 | radial_sector_1 | Coordinate model selects sector index 1; this is a geometry check. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-24 | radial_sector_2 | Coordinate model selects sector index 2; this is a geometry check. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-25 | radial_sector_3 | Coordinate model selects sector index 3; this is a geometry check. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-26 | radial_sector_4 | Coordinate model selects sector index 4; this is a geometry check. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-27 | radial_sector_5 | Coordinate model selects sector index 5; this is a geometry check. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-28 | radial_sector_6 | Coordinate model selects sector index 6; this is a geometry check. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-29 | radial_sector_7 | Coordinate model selects sector index 7; this is a geometry check. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-30 | radial_center_cancels | Center selects no sector. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-31 | radial_outside_cancels | A point outside the wheel selects no sector. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-32 | radial_screen_edge_clamp | Menu bounds stay within the test screen; physical multi-display behavior is not tested. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-33 | current_format_excluded | PNG is absent from PNG conversion targets. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-34 | image_tool_catalog | Image catalog contains seven tools; this count does not execute every tool UI. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-35 | subtitle_conversion | VTT begins with WEBVTT, timestamp becomes 00:00:01.500, and text retains the Chinese greeting. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-36 | metadata_location_removed | Reopened JPEG has no GPS dictionary. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-37 | metadata_author_saved | Reopened JPEG IPTC Byline equals the test value Kris. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-38 | metadata_caption_saved | Reopened JPEG IPTC CaptionAbstract equals Local test. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-39 | metadata_original_preserved | Metadata editing leaves source bytes identical. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-40 | compression_smaller | Compressed output is smaller; this case also enables resizing. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-41 | compression_resize | Decoded longest edge equals 128 pixels. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-42 | partial_batch_keeps_successes | Batch returns one success and one error; successful output exists. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-43 | text_pagination | Long text produces more than one page; this original assertion does not inspect the full tail. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-44 | archive_extract | Extracted note.txt contents match the source exactly. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-45 | archive_convert | System tar listing includes note.txt. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-46 | audio_real_encode | MP3 output exists and exceeds 100 bytes; the original case does not fully decode it. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-47 | video_real_encode | WebM output exists and exceeds 100 bytes; the original case does not decode every frame. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-48 | video_mute_removes_audio | ffprobe finds no audio stream. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-49 | media_trim_duration | ffprobe duration differs from one second by less than 0.1 seconds. | Source assertion satisfied; see the test implementation. | PASS |
| MAC-50 | drag_stale_pasteboard_ignored | Old file drag + held mouse does not activate. | Old file drag + held mouse does not activate. | PASS |
| MAC-51 | drag_fresh_pasteboard_without_event | Fresh file drag activates without an NSEvent callback; physical Shift remains a separate manual check. | Fresh file drag activates without an NSEvent callback; physical Shift remains a separate manual check. | PASS |
| MAC-52 | drag_editor_mouse_ignored | Crop, paint and window drags stay outside the desktop entry. | Crop, paint and window drags stay outside the desktop entry. | PASS |
| MAC-53 | drag_consumed_session_stays_closed | Esc/drop consumes the session until button release. | Esc/drop consumes the session until button release. | PASS |
| MAC-54 | drag_next_session_rearms | Release resets the baseline; a new file drag re-arms. | Release resets the baseline; a new file drag re-arms. | PASS |
| MAC-55 | drag_modern_file_url_read | Private pasteboard with public.file-url. | Private pasteboard with public.file-url. | PASS |
| MAC-56 | drag_legacy_file_paths_read | NSFilenamesPboardType works, duplicates and unsupported extensions are filtered. | NSFilenamesPboardType works, duplicates and unsupported extensions are filtered. | PASS |
| MAC-57 | transparency_png | Corner [0, 0, 0, 0]; half-transparent red center [128, 19, 0, 128], premultiplied RGBA. | Corner [0, 0, 0, 0]; half-transparent red center [128, 19, 0, 128], premultiplied RGBA. | PASS |
| MAC-58 | transparency_webp | Corner [0, 0, 0, 0]; half-transparent red center [128, 19, 0, 128], premultiplied RGBA. | Corner [0, 0, 0, 0]; half-transparent red center [128, 19, 0, 128], premultiplied RGBA. | PASS |
| MAC-59 | jpeg_transparency_white | Transparent corner becomes white: [255, 255, 255, 255]. | Transparent corner becomes white: [255, 255, 255, 255]. | PASS |
| MAC-60 | exif_orientation_applied | EXIF orientation 6 loads as 320×240. | EXIF orientation 6 loads as 320×240. | PASS |
| MAC-61 | exif_orientation_not_applied_twice | Export has normalized pixels and no stale orientation tag. | Export has normalized pixels and no stale orientation tag. | PASS |
| MAC-62 | corrupt_image_rejected | Malformed PNG is rejected. | Malformed PNG is rejected. | PASS |
| MAC-63 | oversized_canvas_rejected | Width above 24000 is rejected before allocation. | Width above 24000 is rejected before allocation. | PASS |
| MAC-64 | outside_crop_rejected | Crop completely outside the image is rejected. | Crop completely outside the image is rejected. | PASS |
| MAC-65 | gps_only_removal_keeps_author | Removing only location preserves the existing author. | Removing only location preserves the existing author. | PASS |
| MAC-66 | gps_preserved_when_requested | Location remains only when removal is disabled. | Location remains only when removal is disabled. | PASS |
| MAC-67 | png_unicode_metadata | PNG author and description survive Unicode round-trip. | PNG author and description survive Unicode round-trip. | PASS |
| MAC-68 | jpeg_compression_preserves_dimensions | JPEG compression without resizing remains 256×256 and shrinks bytes. | JPEG compression without resizing remains 256×256 and shrinks bytes. | PASS |
| MAC-69 | png_compression_shrinks | PNG uses lossy color quantization; size stays 256×256. | PNG uses lossy color quantization; size stays 256×256. | PASS |
| MAC-70 | pdf_compression_page_geometry | Raster compression shrinks bytes and preserves page dimensions within 1 pt; searchable text is not retained. | Raster compression shrinks bytes and preserves page dimensions within 1 pt; searchable text is not retained. | PASS |
| MAC-71 | batch_all_failures_reported | Two missing inputs produce zero successes and two explicit errors. | Two missing inputs produce zero successes and two explicit errors. | PASS |
| MAC-72 | background_custom_color | Custom green background corner: [0, 255, 0, 255]. | Custom green background corner: [0, 255, 0, 255]. | PASS |
| MAC-73 | background_rounded_corner | Rounded image corner reveals the background: [0, 255, 0, 255]. | Rounded image corner reveals the background: [0, 255, 0, 255]. | PASS |
| MAC-74 | background_photo_rendered | Photo background is composited into the exported pixels. | Photo background is composited into the exported pixels. | PASS |
| MAC-75 | annotation_pen_export | Decoded export has 5318 changed color bytes, with actual raster annotation. | Decoded export has 5318 changed color bytes, with actual raster annotation. | PASS |
| MAC-76 | annotation_rectangle_export | Decoded export has 12816 changed color bytes, with actual raster annotation. | Decoded export has 12816 changed color bytes, with actual raster annotation. | PASS |
| MAC-77 | annotation_arrow_export | Decoded export has 8062 changed color bytes, with actual raster annotation. | Decoded export has 8062 changed color bytes, with actual raster annotation. | PASS |
| MAC-78 | annotation_text_export | Decoded export has 6522 changed color bytes, with actual raster annotation. | Decoded export has 6522 changed color bytes, with actual raster annotation. | PASS |
| MAC-79 | redaction_then_blur_stays_hidden | Later blur uses the already redacted pixels; center [0, 0, 0, 255]. | Later blur uses the already redacted pixels; center [0, 0, 0, 255]. | PASS |
| MAC-80 | redaction_then_pixelate_stays_hidden | Later pixelate uses the already redacted pixels; center [0, 0, 0, 255]. | Later pixelate uses the already redacted pixels; center [0, 0, 0, 255]. | PASS |
| MAC-81 | crop_ratio_model | Selecting 1:1 produces 240×240 from 240×320. | Selecting 1:1 produces 240×240 from 240×320. | PASS |
| MAC-82 | crop_pixel_dimensions | Pixel fields drive actual 120×90 output. | Pixel fields drive actual 120×90 output. | PASS |
| MAC-83 | editor_reset_restores_original | Reset restores crop, pixel fields and annotation state. | Reset restores crop, pixel fields and annotation state. | PASS |
| MAC-84 | option_switches_seven_tools | Option changes the JPEG menu to seven tools. | Option changes the JPEG menu to seven tools. | PASS |
| MAC-85 | option_release_restores_formats | Releasing Option restores eight JPEG format targets. | Releasing Option restores eight JPEG format targets. | PASS |
| MAC-86 | mixed_batch_common_actions | PNG + PDF exposes only their common conversions and tools; format order follows the first file. | PNG + PDF exposes only their common conversions and tools; format order follows the first file. | PASS |
| MAC-87 | docx_xml_parts_parse | Content types, package relationships, document and image relationships all parse as XML. | Content types, package relationships, document and image relationships all parse as XML. | PASS |
| MAC-88 | docx_embedded_image_decodes | DOCX contains a real, decodable 240×320 image. Office rendering remains manual. | DOCX contains a real, decodable 240×320 image. Office rendering remains manual. | PASS |
| MAC-89 | text_last_page_contains_tail | OCR of the last rendered page confirms the ending text was not truncated. | OCR of the last rendered page confirms the ending text was not truncated. | PASS |
| MAC-90 | archive_symlink_rejected | ZIP containing a symbolic link is rejected before extraction. | ZIP containing a symbolic link is rejected before extraction. | PASS |
| MAC-91 | audio_stream_fully_decodes | Expected mp3 codec and complete FFmpeg decode without errors. | Expected mp3 codec and complete FFmpeg decode without errors. | PASS |
| MAC-92 | video_stream_fully_decodes | Expected vp9 codec and complete FFmpeg decode without errors. | Expected vp9 codec and complete FFmpeg decode without errors. | PASS |

## Failure history and receipt audit

The first expanded regression run preserved **85 PASS / 1 FAIL**. The failing mixed-file catalog assertion incorrectly fixed shared-format order while the app follows the first file. The assertion was corrected to compare the shared format set and retain tool-order checks. The original failure receipt remains available: [first regression](evidence/first-regression-run.json).

The intentional failure probe records **0 PASS / 1 FAIL**, exit code 1. Its audit verdict is PASS because it proves atomic failure receipts and a nonzero process exit. This deliberate FAIL is not counted as a product functional failure. [Failure probe](evidence/failure-receipt-probe.json)

Earlier 1.0.0 reports remain in the local acceptance materials. Two early runs without final receipts remain UNKNOWN and are excluded from pass totals.

## Clean build and actual CI

The isolated release directory was built from scratch: 92 PASS / 0 FAIL / 0 SKIP; failure-receipt probe PASS. Binary SHA-256: `3d9d439a533e58a67057d994be647e9dadda873a41cd7bae3c50e8c01570aaff`. [Clean-build summary](evidence/clean-build-summary.json)

[GitHub Actions run #37063085729](https://github.com/skynet518/citrus-mac/actions/runs/37063085729) completed successfully. Downloaded artifacts were independently checked: 92 PASS / 0 FAIL / 0 SKIP; failure-receipt probe PASS; app packaging succeeded. Tested source commit: `b0d6d5f964310a49aee2df6e72409e32579023d3`. [CI receipt](evidence/github-ci-verification.json) · [Run summary](evidence/github-ci-summary.json)

CI binary SHA-256: `63f94082eef51b8a6b14ba09215a91f20dfeaeca3581b53faa9beb2e9c7b5dc2`. Builds are listed separately rather than implying identical binaries across build paths. CI did not verify physical Finder modifier-drag gestures. Subsequent evidence and demo commits only update documentation/media and leave the tested native code unchanged.

## Real UI and remaining acceptance

The installed app's file-picker workflow was exercised on 2026-10-03: actual PDF-to-JPG export, crop-handle adjustment and saved copy, background settings and saved output. [Illustrated guide](GUIDE.en.md) · [Media provenance](MEDIA_VALIDATION.md)

Physical Finder gestures, multi-display/Spaces/full-screen behavior, Intel/other macOS releases, Word/Pages rendering, the full conversion/editing matrix, and Developer ID signing/notarization remain outside completed acceptance. A manually dragged crop also showed a one-pixel rounded-field/export difference, recorded in [acceptance](ACCEPTANCE.en.md). Public release is awaiting Kris's confirmation after physical acceptance.
