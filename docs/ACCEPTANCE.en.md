# Mac acceptance checklist

[中文](ACCEPTANCE.md) · [Home](../README.en.md)

2026-10-03: the user authorized a private repository first, with public release to follow acceptance. Windows/Linux work is deferred.

| Item | Status | Evidence or boundary |
| --- | --- | --- |
| PDF → JPG → Crop → Add BG | Implemented; actual file-picker workflow verified | The illustrated guide and demo use native screens and actual exported files |
| Installed in Applications and launchable | Verified | Local installation and native launch |
| White citrus menu bar icon | Drawing verified | Subjective visibility remains open to user feedback |
| Automated functional checks | 92 PASS / 0 FAIL / 0 SKIP | Installed Mac app, clean build, and macOS 26 ARM64 CI; see TESTING.en.md |
| Failure receipt and nonzero exit | Verified | Separate intentional failure probe, excluded from functional pass counts |
| Finder Shift-drag | 1.0.0 failed by user report; 1.0.1 retest pending | User reported no wheel; polling and legacy path reading were added |
| Shift + Option tool switch | State model passed; physical retest pending | State-model checks do not establish system gestures |
| Multiple displays, Spaces, full-screen windows | Not verified | Screen-clamp calculations do not substitute for physical testing |
| Intel and other macOS releases | Not verified | Minimum deployment target does not imply tested compatibility |
| DOCX rendering in Word/Pages | Not verified | XML and embedded images passed structural checks |
| Every input format and media editing combination | Not verified | The complete support matrix is not accepted |
| Apple Developer ID signing and notarization | Incomplete | Current build is ad-hoc signed |
| Public release | Awaiting Kris's acceptance | A private upload is separate from public release |

## Physical desktop retest

1. Open Citrus from Applications and close the welcome window.
2. In Finder, hold Shift while dragging a PDF for about one second. Observe the wheel, release in JPG, and verify a JPG beside the source.
3. Hold Shift + Option while dragging the JPG. Observe the seven tools; release Option to return to formats and press it again to return to tools.
4. Choose Crop, drag the handles, set ratio/pixel values, and click Apply. Run Add BG on the cropped output and save.
5. Try Esc, dropping at the center, and dropping outside the wheel. Cancellation should produce no file.

Activation must belong to a fresh supported-file drag. Crop handles, text selection, and stale drag pasteboard contents should not trigger it.

## Demo update on 2026-10-03

The actual file-picker workflow produced `Citrus Demo.jpg`, `Citrus Demo Cropped (2).jpg`, and `Citrus Demo Cropped (2) BG.jpg`. Native screen captures and the export ledger are in [media validation](MEDIA_VALIDATION.md). These results verify conversion/editor output through the file picker and do not change physical-gesture acceptance.

During the manually dragged crop, displayed rounded pixel fields were 1896 × 1738 while the saved integer-bounded image was 1897 × 1739. Exact handle-drag field/export agreement remains a known rounding detail to review before public release; the existing exact pixel-input automated case is a different path.
