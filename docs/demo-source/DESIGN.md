# Citrus demo — visual and motion decisions

## Brief

Create a short product demonstration for social media and a prominent GitHub
README preview. Deliver a vertical 1080 × 1920 version and a horizontal
1920 × 1080 version, 30 fps, with concise Chinese and English captions.
Also deliver a Xiaohongshu cover at 1080 × 1080 (1:1), and a Douyin cover
at 1080 × 1920 (9:16). Kris explicitly chose light sound cues and bilingual
captions.

The user's supplied 22-second Tangerine clip is a pacing and interaction
reference. Its media and branding will not be included in the deliverables.

## Visual direction

Keep Citrus's actual warm orange glass windows and exported files intact.
Use real screenshots from the installed Citrus 1.0.1 app. A cream canvas
(#FFF7ED), dark warm ink (#2E1C0F), orange (#E3380F), and restrained peach
accents connect the app screenshots to the title and caption rails.

Typography: PingFang SC / Apple system sans for Chinese captions; Georgia
for the large English brand word, with system sans for English instructions.
No borrowed third-party interface, stock UI, or invented controls.

The app is the visual subject. Use generous space, one large screenshot at
a time, clear step numbers, and an unobtrusive provenance footer. No dense
cards, fake device bezel, tiny body copy, or flashing effects.

## Storyboard and timing

1. 0–3.8 s — Citrus identity and the file-to-finished-image promise.
2. 3.8–10.2 s — choose a PDF; show the real format wheel; select JPG; show
   the actual exported JPG.
3. 10.2–17.2 s — show the real tool wheel, open Crop, adjust the crop, and
   show the actual cropped image.
4. 17.2–24.2 s — show Add BG, native padding/corner/shadow controls, and
   the actual background export.
5. 24.2–28 s — final result and repository address.

Use the same story and source assets in both aspect ratios. Layout each
ratio separately so the UI remains readable.

## Motion system

Medium energy. Entrances use small translation and scale changes with
power3.out; pointer moves use power2.inOut; result reveals use expo.out.
Short blur dissolves connect the five scenes, with a matching warm canvas
underneath. Keep final output on screen long enough to inspect.

All motion is deterministic GSAP timeline motion. Preserve the finished
state in the static layout, and animate elements from their entrance state.
Use no CSS animation clocks, random values, or asynchronous timeline setup.

## Evidence and editorial boundaries

Screen captures and file outputs must come from the installed app.
Cursor movement and transitions will be recreated for clarity. Label this
in both video captions and documentation: "实际界面 · 光标动效重演 /
Actual UI · cursor motion recreated".

Use the verified file-picker workflow. Do not present Finder Shift or
Shift+Option activation as an accepted working interaction: the physical
retest remains pending. The README must keep that acceptance boundary.

Do not copy the source/reference video into the project or GitHub. Capture
only the app window, without home-folder panels or unrelated user data.
Kris explicitly requires privacy: only demo filenames and demo folder names
may appear in outward-facing media. Do not use file-picker or Finder screenshots
that expose the actual workspace, recent items, other files, or user paths.
Audit exported frames and screenshots before uploading them.

Sound: prepare subtle, original UI cues without third-party music or online
voice providers. The user may choose silent or voiceover while visuals are
being produced; default to the stated light-cue version if no preference
arrives. GitHub's animated preview is silent.

## Delivery and verification

Deliver H.264 MP4 with yuv420p and AAC where sound is present. Provide a
silent loop GIF and a still poster for GitHub, numbered native screenshots,
Chinese and English guides, editable animation source, and an asset ledger.

Run HyperFrames checks, inspect representative frames and transitions,
review the full render, verify duration/dimensions/codecs and local media
links, and verify the rendered README after pushing the private repository.
