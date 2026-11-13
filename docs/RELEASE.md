# Release packaging

Run `bash package-release.sh` from the project root. The script builds the optimized arm64 app, runs self-tests, verifies its ad hoc signature, and archives the complete bundle with macOS metadata. It extracts the ZIP, verifies the extracted signature, reruns self-tests, and generates and checks a SHA-256 checksum. The version comes from [Info.plist](../Resources/Info.plist).

The current local release is `v0.4.0`. Its package files are:

- `build/release/Notch-Musique-0.4.0-macOS-arm64.zip`
- `build/release/Notch-Musique-0.4.0-macOS-arm64.zip.sha256`

Packaging does not publish a GitHub release. Generated artifacts remain in the ignored `build/` folder.

The user requested local packaging, a commit if needed, and a release tag. Version 0.4.0 includes the compact Media/Calendar/Focus panel, artwork at rest, Spotify seeking, opt-in EventKit agenda, automatic focus/break cycles with skip and duration choices, and the application icon. The release is recorded in a local commit with an annotated `v0.4.0` tag. No remote publication is part of this request. Future releases should commit the source and validation record, then tag that exact commit after packaging succeeds.

## Suggested release notes

Notch Musique 0.4.0 requires an Apple Silicon Mac, macOS 13 or later, Spotify desktop for media playback, and a notched display for the overlay. This binary does not support Intel Macs.

New in this release: a compact three-tab panel; artwork and activity status at rest; a Spotify position slider; an upcoming-events list from calendars configured in macOS; automatic 25/5 focus/break cycles with pause/resume, skip, presets and saved duration choices; and a macOS application icon. Calendar access is requested only through the connect button. The timer does not change macOS system Focus settings.

Extract the ZIP, quit any previous instance, and move `Notch Musique.app` to Applications. Launch it and allow Spotify automation when requested. Keep the app in a stable location before enabling launch at login.

The app is ad hoc signed and is not notarized by Apple. macOS may block the downloaded app. Downloaded-app approval has not been validated locally.

Place the ZIP and checksum in the same directory and verify with:

```sh
shasum -a 256 -c Notch-Musique-0.4.0-macOS-arm64.zip.sha256
```

The built and extracted app each passed all 31 self-test assertions, and signatures and the archive checksum verified. Calendar access with real accounts, some playback gestures, launch at login and additional display configurations still need manual validation. See [actual validation results](VALIDATION.md).
