# Release packaging

Run `bash package-release.sh` from the project root. The script builds the optimized arm64 app, runs self-tests, verifies its ad hoc signature, and archives the complete bundle with macOS metadata. It extracts the ZIP, verifies the extracted signature, reruns self-tests, and generates and checks a SHA-256 checksum. The version comes from [Info.plist](../Resources/Info.plist).

Upload these files to a GitHub release tagged `v0.3.0`:

- `build/release/Notch-Musique-0.3.0-macOS-arm64.zip`
- `build/release/Notch-Musique-0.3.0-macOS-arm64.zip.sha256`

Packaging does not publish a GitHub release. Generated artifacts remain in the ignored `build/` folder.

## Suggested release notes

Notch Musique 0.3.0 requires an Apple Silicon Mac, macOS 13 or later, Spotify desktop, and a notched display for the contour. This binary does not support Intel Macs.

Extract the ZIP, quit any previous instance, and move `Notch Musique.app` to Applications. Launch it and allow Spotify automation when requested. Keep the app in a stable location before enabling launch at login.

The app is ad hoc signed and is not notarized by Apple. macOS may block the downloaded app. Downloaded-app approval has not been validated locally.

Place the ZIP and checksum in the same directory and verify with:

```sh
shasum -a 256 -c Notch-Musique-0.3.0-macOS-arm64.zip.sha256
```

See [actual validation results](VALIDATION.md) for checks and remaining manual validation, including Spotify controls, launch at login and additional display configurations.
