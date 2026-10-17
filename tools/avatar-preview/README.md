# GymRats local Avatar Lab

Four real rigged models downloaded for a local joint-motion feasibility check.
This is a standalone development tool, not an integration into the Flutter app.

## Run

Run `Start-Avatar-Preview.ps1` in PowerShell, then open http://127.0.0.1:8765.
The launcher uses the local bundled Python runtime, falling back to `python` on PATH.
Alternatively run `python serve.py` in this folder, and keep that terminal open.
Do not open index.html directly: GLB/module loading requires HTTP.
The local server maps `/native-assets/` to the committed Flutter avatar assets,
so `test-native-bridge.html` needs no machine-specific directory junction.
The server listens only on 127.0.0.1. No webcam access or external service is required.
Close the viewer tab to stop viewing; the hidden local server stays available until stopped or the computer restarts.

## Controls

- Select a model at the top.
- Choose a bone, then adjust its local X/Y/Z rotation sliders.
- Select an automatic-test axis and press the motion button for a sine-wave joint sweep.
- Reset restores all bones to their initial local rotations.
- Skeleton and wireframe toggles help inspect skinning.
- Drag to orbit, wheel to zoom, right-drag to pan.

Rotations are relative to each model's own bind-pose axes. The same axis does not
necessarily bend the same anatomical joint in the same way across models.
These are procedural test rotations, NOT captured human motion or the source animation clips.
This browser page remains a manual inspection tool; it does not request a webcam.
The Flutter app now has a separate ML Kit-to-avatar bridge (see below).

## Files and provenance

- `source-assets/`: local downloaded originals and original license documents. Download archives, author-page HTML and Blender/FBX originals are excluded from Git; license documents are retained.
- `models/`: derived GLB files and source-rig inspection JSON.
- `vendor/three/`: the required Three.js 0.180.0 modules, MIT; original LICENSE is retained there. Unused modules and download archives are excluded from Git.
- `download_assets.py`: original-asset downloader.
- `inspect_blend.py`: source rig inspection (run through Blender).
- `convert_models.py`: safe offline conversion (run through Blender).

GLB conversion used official portable Blender 4.5.3 with `--background --factory-startup --disable-autoexec`.
Embedded source scripts were not run. The original files were not modified.
Conversion selected only the avatar, removed pose constraints, cleared active animation and
reset the pose. Mannequiny and XCVG legacy material alpha was set opaque to restore visibility.
The exporter retains at most four skin weights per vertex; this preview is not a lossless replacement for the originals.
GLB loader sanitizes punctuation from some bone names (for example `UpperArm.L` becomes `UpperArmL`).
Future protocol mappings must account for this.

## Credits / licenses

| Model | Creator / source | Asset license |
| --- | --- | --- |
| Rigged Low Poly Astronaut | MrLentereng (rigging), ThunderWare Games (original); https://mrlentereng.itch.io/rigged-low-poly-astronaut | CC0 |
| Corebreaker Robot | Donitz; https://donitz.itch.io/corebreaker-robot-model | CC0 |
| GDQuest Mannequiny | GDQuest; https://github.com/gdquest-demos/godot-3d-mannequin | Art: CC BY 4.0; code: MIT |
| Rigged and Animated Humanoid | XCVG; https://opengameart.org/content/rigged-and-animated-humanoid | CC0 |

CC0: https://creativecommons.org/publicdomain/zero/1.0/

CC BY 4.0: https://creativecommons.org/licenses/by/4.0/

Mannequiny's original full license is retained in `source-assets/mannequiny-LICENSE.txt`.
XCVG's license is retained in `source-assets/xcvg/COPYING.txt`.
Mannequiny attribution, source link, license link and the above change notice must accompany redistribution.

## Local verification (2026-10-15)

All four GLB files loaded and rendered in the local browser; upper-arm slider rotation was visually checked.
Loaded bone counts (including FBX end bones where present): Astronaut 66, Robot 58, Mannequiny 45, XCVG 65.
This does not establish anatomical correctness of every joint or suitability for real-time pose retargeting.
This section records the initial local model inspection, before online integration.

## Flutter: existing ML Kit camera → avatar toggle (2026-10-15)

The setup screen, rep-judge demo, and battle screen now share `PoseAvatarToggleView`.
Tap **아바타 보기 / 카메라 보기** to change the presentation without restarting the
existing camera, pose detector, judge, counter or battle timer.
Long-press that same button to choose any of the four models. Selection is local
to that preview screen, not yet a saved user setting or an online avatar message.

Run the app normally from `gymrats_app`, or use the existing detector demo:

```powershell
flutter run -t lib/demo/rep_judge_demo.dart -d <device-id>
```

Data flow: existing `PoseEstimator` → `PoseFrame` → `avatarPosePayload` → local
WebView JavaScript channel → bundled Three.js / GLB → `PoseRetargeter`.
The WebView never opens a camera and never runs a second detector. Raw video is
not passed to JavaScript, recorded, or uploaded. Assets are bundled and loaded
via `loadFlutterAsset`, not a phone/PC HTTP server or external CDN.

ML Kit x/y/z are image-space values, not metric MediaPipe world landmarks. All
three axes are scaled by image width to preserve geometric directions. Missing,
invalid or low-confidence points are ignored and relaxed toward the bind pose.
Arm/leg segment directions, feet, torso orientation and neck direction are mapped;
bone lengths are retained. Twist, finger/face tracking, IK, metric depth translation,
accurate floor contact are not implemented. The online battle now synchronizes
joint coordinates and avatar identifiers using the session protocol.
Single-camera depth and occlusion still limit how faithfully a push-up is shown.

Native renderer source: `native-renderer.js` + `retarget.js`.
Rebuild with `build-native.ps1` after editing these. Generated output, licenses
and the four GLBs are under `gymrats_app/assets/avatar/`.
The WebView dependency requires Android API 24+; no cleartext-network exception
or additional camera permission was introduced.

Checks: Flutter suite 334 tests passed, four actual GLB rigs passed direction /
lost-tracking / reset checks, and the bundled renderer displayed all four using
synthetic landmarks through the same JavaScript bridge. No Android device was
attached, so live phone-camera rendering and device performance still need an
on-device check. These checks do not establish perfect anatomical retargeting.

The paragraph above records the initial 2026-10-15 checks. By 2026-10-17 the
app had been installed on a phone and an emulator, and the user confirmed their
online interoperability. See `../../docs/iteration-2-protocol.md` for current
online setup, synthetic-opponent limitations and remaining validation.

### Screen-relative body movement

The Flutter payload now preserves a separate `screenAnchor`: the original hip
midpoint normalized by image width/height, plus the image aspect ratio. Centered
landmarks still control joint rotations. `ScreenRootMotion` maps the hip midpoint
to the same screen location using the camera preview's centered cover crop and
the renderer's perspective camera. It compensates the actual pelvis bone's
position after posing, rather than pinning the model origin. Existing canvas
mirroring also mirrors the translated model, without double-flipping the data.
Translation is smoothed and low-confidence/out-of-frame hips are ignored. After
tracking is lost, position returns toward its default along with the bind pose.
This implements screen X/Y motion, not real-world travel distance, absolute
camera depth, automatic body-size scaling, IK or floor contact.

Regression test: `node tools/avatar-preview/test-screen-root-motion.mjs` from
the repository root checks portrait/landscape crops, moving pelvis pivots,
projection alignment, fixed depth, lost tracking and reset.

### Elbow emphasis (display only)

The native avatar adds a screen overlay at each rendered elbow: a ring, bend
arc, thicker upper/forearm guide and left/right angle badge. Bent arms have a
stronger warm accent; the color is NOT a pass/fail judgment. The badge uses the
same image-plane shoulder–elbow–wrist definition as Flutter `angleDegrees`,
ignoring z, with temporal smoothing for display. Low-confidence/missing arms
are hidden rather than showing an old angle. Model rotations, detector output,
rep counting and thresholds are unchanged. Mirroring is applied to both the
rendered model and overlay coordinates, while badge text stays readable.

Test: `node tools/avatar-preview/test-elbow-highlight.mjs` checks 180/90/60-degree
angles, missing/invalid points, visibility gating, mirrored drawing, and no
mutation of landmarks or bone rotations.
