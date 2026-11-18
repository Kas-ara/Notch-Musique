# Release packaging

Run `bash package-release.sh` from the project root. The script builds the optimized arm64 app, runs self-tests, verifies its ad hoc signature, and archives the complete bundle with macOS metadata. It extracts the ZIP, verifies the extracted signature, reruns self-tests, and generates and checks a SHA-256 checksum. The version comes from [Info.plist](../Resources/Info.plist).

Packaging creates the versioned ZIP and checksum under the ignored `build/release/` directory.

## Proposed release notes for v0.5.0

- Notch Musique is now Notch multitools. The app keeps its bundle identifier and preference keys so it can read existing settings.
- The interface and macOS permission descriptions are available in English and French. The app follows macOS language preferences and falls back to English.
- A new Countdown tab saves a custom label and target date. When Spotify is idle, the countdown can appear beside the notch. Active focus sessions and imminent meetings retain priority.

The app requires macOS 13 or later on Apple Silicon. The overlay requires a notched display and media controls require Spotify desktop.

Quit the previous app before opening the renamed bundle. The ZIP contains an ad hoc signed app without Apple notarization. Downloaded-app Gatekeeper approval remains unverified.

Place the ZIP and checksum in the same directory and verify with:

```sh
shasum -a 256 -c Notch-multitools-0.5.0-macOS-arm64.zip.sha256
```

## Release notes for v0.4.0

Notch Musique 0.4.0 requires an Apple Silicon Mac, macOS 13 or later, Spotify desktop for media playback, and a notched display for the overlay. This binary does not support Intel Macs.

New in this release: a compact three-tab panel; artwork and activity status at rest; a Spotify position slider; an upcoming-events list from calendars configured in macOS; automatic 25/5 focus/break cycles with pause/resume, skip, presets and saved duration choices; and a macOS application icon. Calendar access is requested only through the connect button. The timer does not change macOS system Focus settings.

Extract the ZIP, quit any previous instance, and move `Notch Musique.app` to Applications. Launch it and allow Spotify automation when requested. Keep the app in a stable location before enabling launch at login.

The app is ad hoc signed and is not notarized by Apple. macOS may block the downloaded app. Downloaded-app approval has not been validated locally.

Place the ZIP and checksum in the same directory and verify with:

```sh
shasum -a 256 -c Notch-Musique-0.4.0-macOS-arm64.zip.sha256
```

The built and extracted app each passed all 31 self-test assertions, and signatures and the archive checksum verified. Calendar access with real accounts, some playback gestures, launch at login and additional display configurations still need manual validation. See [actual validation results](VALIDATION.md).
