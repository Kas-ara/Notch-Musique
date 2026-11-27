# Notch multitools logo

Created November 13, 2026 at the user's request with the built-in imagegen tool. Final asset: [logo.png](logo.png), 1254 × 1254 RGBA PNG with an alpha channel. Original branding for this project, without Apple or Spotify logos.

The asset is offered under the repository's MIT license. No trademark clearance search has been performed.

## macOS application icon

The application uses this same logo as its bundle icon. [AppIcon.icns](../Resources/AppIcon.icns) contains the standard and Retina representations from 16 to 1024 pixels, preserving the original artwork and transparency. [The build script](../build.sh) copies it into `Contents/Resources` before signing; `CFBundleIconFile` in [Info.plist](../Resources/Info.plist) selects it. The waveform status-bar symbol remains separate from the application icon.

To regenerate the ICNS after replacing the logo, run `bash generate-icon.sh` from the project root, then rebuild. [The icon packaging script](../generate-icon.sh) uses macOS `sips` and `iconutil`; it does not generate new artwork. No external dependency is required.

## Generation prompt

```text
Use case: logo-brand. Asset type: original logo for the open-source macOS app 'Notch Musique'. Create ONE polished, very minimal standalone brand symbol, no text or letters. The app is a discreet music progress contour around a MacBook screen notch. Symbol: a wide black rounded notch/capsule with a crisp electric-blue partial progress outline wrapping its left edge and curved bottom, plus a very small elegant audio wave inside in warm white. Flat vector-like geometry, restrained macOS craftsmanship, clear silhouette readable at small icon sizes, ample transparent padding, square composition. Real transparent background outside the symbol. No Spotify logo, no Apple logo, no mockup, no shadows, no gradients, no watermark, no extra objects. High resolution.
```
