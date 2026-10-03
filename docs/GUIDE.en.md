# Citrus: finish a demo image in five steps

[Home](../README.en.md) · [中文](GUIDE.zh-CN.md) · [Watch the 28-second demo](media/citrus-demo-horizontal-zh-en.mp4)

This guide uses actual Citrus 1.0.1 screens: choose a file, click the wheel, and save a copy. Screenshots contain only app windows, and all example files were made for this project. Physical Finder Shift / Shift+Option activation is still awaiting retest; see [acceptance](ACCEPTANCE.en.md).

## 1. Launch and select the demo PDF

Move the built `橘子.app` into Applications and open it. Click **选择文件…** (Choose files) in the welcome window. After closing that window, use the white citrus menu bar icon and choose **选择文件…** again.

<img src="images/01-welcome.png" alt="Actual welcome window with the Choose files button at the bottom" width="430">

Download [Citrus Demo.pdf](demo-files/Citrus%20Demo.pdf) into a folder you create called `Citrus Demo`. Select the PDF in the file picker and open it. The screenshots omit the file picker, recent items, and desktop to protect workspace privacy.

## 2. Click JPG on the wheel

For a PDF, the wheel offers **JPG, PNG, DOCX, TXT**. Click **JPG** and wait for processing.

<img src="images/02-format-wheel.png" alt="Actual PDF format wheel; JPG is at the top" width="340">

`Citrus Demo.jpg` appears beside the PDF. Existing filenames receive a numeric suffix, and the PDF is preserved. Compare the [actual exported JPG](demo-files/Citrus%20Demo.jpg).

## 3. Choose the JPG and open Crop

Use **选择文件…** to select the generated JPG. Press **Tab** to switch to the tools wheel, then click **Crop**. The seven tools are Compress, Metadata, Edit, Annotate, Add BG, Crop, and Redact.

<img src="images/04-tools-wheel.png" alt="Actual JPG tool wheel with Crop at the lower left" width="340">

Arrow keys move selection, Enter runs it, `Tab` switches between formats and tools, and `Esc` closes the wheel.

## 4. Adjust the crop and click Apply

Drag the orange corner or edge handles to keep the citrus shape inside the selection. You can also use **Aspect ratio** buttons and **W / H** pixel fields. **Reset** restores the initial selection. Click **Apply** at the lower right to save.

| Initial crop window | Adjusted selection |
| --- | --- |
| <img src="images/05-crop-before.png" alt="Actual crop window with the full image selected" width="360"> | <img src="images/07-crop-final.png" alt="Actual crop window with the citrus shape selected" width="360"> |

A new copy receives the `Cropped` suffix. This demo uses [Citrus Demo Cropped (2).jpg](demo-files/Citrus%20Demo%20Cropped%20%282%29.jpg); the number comes from repeated operations, so your first export may have no number. The result stays beside the source.

## 5. Add a background to the cropped image

Select the cropped JPG, press **Tab**, and click **Add BG**. Choose a gradient or solid color; the image button can select a background photo.

| Initial background | Finished demo settings |
| --- | --- |
| <img src="images/08-background-before.png" alt="Actual initial Add BG window" width="360"> | <img src="images/09-background-final.png" alt="Actual completed Add BG window with blue background and 16:9 ratio" width="360"> |

The demo uses the second, blue gradient with **Padding 520 px, Corners 144 px, Shadow 72 px, Ratio 16:9**. These values suit the demo crop; adjust them for your own images.

Click **Save with Background** to create a copy with the `BG` suffix. Compare the [actual final export](demo-files/Citrus%20Demo%20Cropped%20%282%29%20BG.jpg):

![Actual 16:9 background image exported by Citrus](demo-files/Citrus%20Demo%20Cropped%20%282%29%20BG.jpg)

## If the window or output is missing

- **Welcome window closed:** use the white citrus menu bar icon to open instructions or choose files. Citrus is a menu bar app.
- **Output location:** check the source folder for a numbered result. The source is preserved.
- **Wheel closed:** choose the file again or check whether `Esc` was pressed. Dropping at the center or outside the wheel cancels drag operations.
- **Finder modifier gestures:** record the result using the [physical retest procedure](ACCEPTANCE.en.md#physical-desktop-retest). This entry is not accepted yet.
- **Audio/video actions:** install local FFmpeg. The demonstrated image workflow does not require the audio/video conversion feature.

[Full functionality tests](TESTING.en.md) · [Limits and acceptance](ACCEPTANCE.en.md) · [Videos and covers](MEDIA.md)
