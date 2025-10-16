# Design Assets

This directory stores the source artwork for the Math Solver app icon so the rasterized assets inside `Assets.xcassets/AppIcon.appiconset` can be regenerated deterministically if needed.

## App Icon workflow

1. Edit `AppIcon.svg` in your preferred vector tool.
2. On macOS, export the PNG renditions required by iOS using the helper script below (requires Xcode command-line tools for `sips`). The asset catalog PNGs are ignored by git so binary blobs never show up in pull requests.

   ```bash
   ./export_app_icon_pngs.sh "$(pwd)/AppIcon.svg" "../MathSolverApp/Assets.xcassets/AppIcon.appiconset"
   ```

   The script removes any existing PNGs in the target app icon set, renders each required size (20, 29, 40, 60, 76, 83.5 at the appropriate scales plus the 1024 marketing icon), and writes the filenames expected by `Contents.json`.
3. Build the Xcode project or run the script whenever the SVG source changes. A Run Script build phase regenerates the PNGs automatically before the asset catalog is compiled, so no manual check-in of binary files is required.

The helper script is idempotent and can be rerun whenever the SVG source changes.
