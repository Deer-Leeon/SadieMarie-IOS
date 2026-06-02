# Admin dashboard fonts

Download from [Google Fonts](https://fonts.google.com/) and add **only** these files to the **SadieMarie** app target.

## Required files

| File name (save as) | Role | Used for |
|---------------------|------|----------|
| `BodoniModa-Regular.ttf` | Bodoni Moda Regular (variable font) | Time column (16pt) |
| `DMSans-Regular.ttf` | DM Sans Regular | Service subtitle (12pt) |
| `DMSans-Medium.ttf` | DM Sans Medium | Client name (14pt), status pills (10pt), day headers (10pt semibold via Medium) |

Optional later: `BodoniModa-Medium.ttf` if you add semibold time styling.

## PostScript names (must match `AdminTheme`)

After installing, run the app once and check the Xcode console, or use Font Book → Bodoni Moda / DM Sans → **PostScript name**.

`AdminTheme` uses these PostScript names (logged at launch in Debug):

- `BodoniModa-Regular` — time column (list + calendar)
- `DMSans-Regular` — subtitles, day numbers
- `DMSans-Medium` — client names, pills, badges

If previews look like SF Pro, the `.ttf` files are missing from the target or `UIAppFonts` in `Info.plist`. Check the Xcode console for `⚠️ [AdminFont] Missing …` on launch.

## Where to put files in the project

```
SadieMarie/
  Fonts/
    BodoniModa-Regular.ttf
    DMSans-Regular.ttf
    DMSans-Medium.ttf
    README.md          ← this file
```

1. Drag the three `.ttf` files into `SadieMarie/Fonts/` in Xcode.
2. Target membership: **SadieMarie** only.
3. **Build Phases → Copy Bundle Resources** should list all three fonts.

## Info.plist

Target **SadieMarie** → **Info** → **Fonts provided by application** (`UIAppFonts`):

```xml
<key>UIAppFonts</key>
<array>
  <string>BodoniModa-Regular.ttf</string>
  <string>BodoniModa-Regular.ttf</string>
  <string>DMSans-Regular.ttf</string>
  <string>DMSans-Medium.ttf</string>
</array>
```

Paths are filenames only (fonts live at the bundle root after copy).
