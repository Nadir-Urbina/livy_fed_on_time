# ASSETS.md — Higgsfield generation log

Every visual asset in this app was generated live via the **Higgsfield MCP**
(`generate_image` / `generate_video`, model `nano_banana_pro` → served as
`nano_banana_2`; video via `kling3_0_turbo`) during the build, in one cohesive
chunky voxel-art style. The **granny master** (first entry) is the locked
style/character reference: every subsequent call passed its job ID as a
reference image. Files were downloaded from the returned URLs, resized with
`sips`, and wired into `pubspec.yaml`.

Reproducibility: each row lists the bundle path, final size, the Higgsfield job
ID, and the prompt used. Reference-locked prompts began with "Same voxel …
character from the reference image, identical style, colors, proportions and
deep indigo-navy background (#171935)." — abbreviated below as **[REF]**.

## Style anchor

| Path | Size | Job ID | Prompt (summary) |
|---|---|---|---|
| `assets/mascots/granny/master.png` | 1024² | `9cb5bb25` | Voxel art granny mascot "Livy": rounded cube silhouette, amber/coral knitted cardigan in blocky voxel folds, silver-white voxel hair in a bun, square-pixel eyes behind small round gold glasses, knowing smile, teacup; chunky faceted cubes, soft AO, toy-like studio lighting; solid #171935 background; collectible designer-toy look |

## Granny pose set (reference-locked to `9cb5bb25`)

| Path | Size | Job ID | Pose prompt |
|---|---|---|---|
| `assets/mascots/granny/pose_proud.png` | 640² | `37043fa5` | [REF] PROUD CHEER — arms raised, joyful, voxel sparkles |
| `assets/mascots/granny/pose_thoughtful.png` | 640² | `3ef1d645` | [REF] THOUGHTFUL — hand on chin, glowing voxel lightbulb |
| `assets/mascots/granny/pose_concerned.png` | 640² | `8082eb94` | [REF] CONCERNED BUT WARM — hands clasped, kind concern, never alarming |
| `assets/mascots/granny/pose_delighted.png` | 640² | `abf4ff5e` | [REF] DELIGHTED — hands to cheeks, voxel hearts and stars |
| `assets/mascots/granny/pose_sleepy.png` | 640² | `58a6132f` | [REF] SLEEPY — nightcap, glowing candle lantern |

## Idle loop (video → sprite frames)

| Path | Size | Job ID | Prompt |
|---|---|---|---|
| `assets/mascots/granny/idle/frame_00..15.png` (16 frames) | 512² | `5b32a987` (kling3_0_turbo, 5 s, start_image = master) | Seamless idle loop: gentle rock/sway, slow breathing, occasional blink, tea sip near the end; camera and background completely static; last frame ≈ first frame. Frames extracted with `ffmpeg -vf "fps=16/5,scale=512:512"`; played ping-pong in `MascotView` for a seamless loop |

## Alternate mascot skins (same rig; poses locked to each master)

| Path | Size | Job ID | Prompt (summary) |
|---|---|---|---|
| `assets/mascots/grandpa/master.png` | 1024² | `7119883e` | New character, same voxel style: wise grandpa — silver voxel mustache, gold glasses, forest-green cardigan vest, baby bottle |
| `assets/mascots/grandpa/pose_{proud,thoughtful,concerned,delighted,sleepy}.png` | 640² | `9ba05381`, `564d88aa`, `0ffa6665`, `d43e0ecc`, `09585def` | [REF grandpa] same five poses as granny |
| `assets/mascots/owl/master.png` | 1024² | `1ec59a8e` | New character, same voxel style: night owl — lavender-grey/cream voxel feathers, amber eyes, reading glasses, plum scarf, moon charm |
| `assets/mascots/owl/pose_{proud,thoughtful,concerned,delighted,sleepy}.png` | 640² | `4c7ce07f`, `057071fb`, `8daec80a`, `66b8ded0`, `2e13cb68` | [REF owl] same five poses |
| `assets/mascots/robot/master.png` | 1024² | `75557cd2` | New character, same voxel style: gentle robot nanny — cream/sage-mint panels, glowing amber eyes, star antenna, coral apron, bottle |
| `assets/mascots/robot/pose_{proud,thoughtful,concerned,delighted,sleepy}.png` | 640² | `f69c10f3`, `7c644a56`, `d2fc693c`, `b19192c2`, `f2aec113` | [REF robot] same five poses |

## Badge catalog (all reference-locked to `9cb5bb25`)

| Path | Size | Job ID | Motif |
|---|---|---|---|
| `assets/badges/ontime_3.png` | 512² | `b9931f8f` | Bronze medallion, voxel alarm clock, stars |
| `assets/badges/ontime_7.png` | 512² | `25c2f260` | Silver medallion, voxel pocket watch, ribbon |
| `assets/badges/ontime_30.png` | 512² | `17930294` | Gold medallion, radiant sun-clock, laurels |
| `assets/badges/logging_3.png` | 512² | `bc6aa704` | Bronze medallion, open notebook + pencil |
| `assets/badges/logging_7.png` | 512² | `e508411c` | Silver medallion, ledger book + quill |
| `assets/badges/logging_30.png` | 512² | `249031cb` | Gold medallion, chest of glowing scrolls |
| `assets/badges/tagteam_first.png` | 512² | `26b81115` | Copper medallion, two hands high-five + heart |
| `assets/badges/tagteam_7.png` | 512² | `2bc41be4` | Gold medallion, bottle passed as relay baton |
| `assets/badges/feeds_50.png` | 512² | `c0d2f57c` | Bronze medallion, proud bottle + star arc |
| `assets/badges/feeds_100.png` | 512² | `0f6b3855` | Silver medallion, bottle pyramid + crown |
| `assets/badges/feeds_250.png` | 512² | `8dd488cc` | Blue/gold medallion, bottle constellation |

## Icons & art (reference-locked to `9cb5bb25`)

| Path | Size | Job ID | Prompt (summary) |
|---|---|---|---|
| `assets/icons/icon_bottle.png` | 512² | `c673ff02` | Voxel baby bottle, amber milk glow, coral cap |
| `assets/icons/icon_can.png` | 512² | `0e2acb66` | Voxel formula tin + scoop, amber label band |
| `assets/icons/icon_shield.png` | 512² | `fff85365` | Calm coral/cream voxel alert shield (recalls) |
| `assets/icons/icon_moon.png` | 512² | `589d25bb` | Glowing voxel crescent moon + stars |
| `assets/art/onboarding_hero.png` | 1600×900 | `f65eee9a` | Voxel nursery at night: granny in rocking chair, crib, glowing nightlight, starry window |
| `assets/art/share_bg.png` | 1600×900 | `405c5385` | Voxel night sky background: indigo clouds, stars, crescent moon (no characters) |
| `assets/art/launch.png` | 1013×1800 | `6d65b1b2` | Vertical launch art: granny with lantern under vast voxel night sky (also feeds `LaunchImage@1x/2x/3x`) |
| `assets/art/celebration_burst.png` | 512² | `d77176a3` | Radial voxel confetti burst, warm palette, clear center |
| `assets/art/app_icon.png` | 2048² | `a92171cb` | App icon: granny bust portrait, warm amber nightlight halo, full-bleed #171935 (resized into every slot of `ios/Runner/Assets.xcassets/AppIcon.appiconset`) |

## Fallback policy

Every `Image.asset` in the app has an `errorBuilder` that falls back to a
tasteful vector placeholder, and `MascotAssetResolver` degrades pose → master →
default mascot. No Material icon or emoji ships as final art for any generated
asset; system icons appear only as UI chrome (navigation, small glyphs) and as
last-ditch fallbacks if a file were removed from the bundle.

## Wave 4 — Daytime art set (time-adaptive theme)

The app now follows the sun (day / dusk / night palettes). Dusk and night share
the original indigo art; the day palette loads these daylight variants, all
generated with nano_banana_pro using each night asset's job as the character
reference plus "re-lit for DAYTIME … solid flat warm cream background (#FAF3E1)".

| Asset path | Size | Higgsfield job |
|---|---|---|
| assets/mascots/granny/day/master.png | 1024² | 7d0095d8-b5f1-400b-aefe-c64767fbade8 |
| assets/mascots/granny/day/pose_proud.png | 1024² | b2838a1a-f7a5-4d29-8701-8e89241b9eb6 |
| assets/mascots/granny/day/pose_thoughtful.png | 1024² | 29c145c5-fba9-4d3a-aadb-c48c4a419dcf |
| assets/mascots/granny/day/pose_concerned.png | 1024² | 520b26b3-d684-4fde-aea2-07c4271527d1 |
| assets/mascots/granny/day/pose_delighted.png | 1024² | 4dea6ef9-e0f0-43b5-9a3d-8cb242b29680 |
| assets/mascots/granny/day/pose_sleepy.png | 1024² | 3c0c5ce2-8f33-4824-9450-e8940d798a12 |
| assets/mascots/granny/day/idle/frame_00–15.png | 512² ×16 | video dd2f6b04-a919-43fc-b8fb-5adb85ab0eca (kling3_0_turbo 5s → ffmpeg fps=16/5) |
| assets/mascots/grandpa/day/master.png + 5 poses | 1024² | 201bd2e2, deb14f8c, 4bd1de2d, a830060a, 81461cff, 7a219555 |
| assets/mascots/owl/day/master.png + 5 poses | 1024² | 42e38d68, 159cac29, a4765ec2, ad6760df, 8ed68c1c, f7b1056b |
| assets/mascots/robot/day/master.png + 5 poses | 1024² | 180a5344, 173be670, cf6f9c51, c7965005, a11097c3, c52da06f |
| assets/icons/day/icon_bottle.png | 1024² | 82fa9b5d-a28b-4f62-a846-fce05172d74c |
| assets/icons/day/icon_can.png | 1024² | 7606b6da-680d-4b2f-9995-35617164628a |
| assets/icons/day/icon_shield.png | 1024² | 6a35cf13-b898-477e-8f47-4b1633a037e2 |
| assets/icons/day/icon_moon.png (voxel sun) | 1024² | 9cd843dc-0913-41db-bf25-7d859a3ac118 |
| assets/art/day/onboarding_hero.png | 2752×1536 | ebe50415-335d-48ad-99f2-96ddf50f3e3c |

Resolution logic: `MascotAssetResolver` prefers `<dir>/day/<file>` when the day
palette is active and the variant exists; otherwise it falls back to the night
art (used as-is at dusk and night).
