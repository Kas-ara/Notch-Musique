# Development and handoff

Status: November 13, 2026. Sources: user requests, source code and local checks. This project is self-contained; neighboring files are not required.

## Confirmed requirements

MacBook Air M5, Spotify desktop, and a discreet contour around the physical notch. On hover, the contour itself expands to contain playback information. Color and thickness are customizable; compact dimensions follow stroke thickness with one point of technical padding. The README should be humorous, centered and illustrated with a logo, emojis and screenshots. The user subsequently requested English documentation for an international audience.

## Architecture

- `Sources/main.swift`: Dockless AppKit application, transparent window, placement, event-based pointer tracking, menus, settings and screenshot export.
- `Sources/NotchView.swift`: SwiftUI views, contour, progress and expansion.
- `Sources/Spotify.swift`: reused AppleScript scripts, metadata, position interpolation, controls and thumbnails.
- `Sources/Appearance.swift`: local preferences and appearance window.
- `Resources/Info.plist`: identity, version and automation permission message.
- `build.sh`: optimized arm64 compilation and ad hoc signing.

## Implementation decisions

Notch geometry comes from `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`. No Mac model is hard-coded. Screens without a notch retain only the menu.

Progress follows an open path: left edge → rounded bottom → right edge. Compact width is physical width + twice (thickness + 1); compact height is physical height + thickness + 1. Expanded width is at least 340 points; height is compact height + 133 points. SwiftUI uses a damped spring, a 280 ms collapse delay, and final window resizing after collapse completes.

## Optimization

Native and SwiftUI hover events are backed by a 250 ms check (80 ms in the prototype). Events alone were insufficient during automated testing, so the fallback remains. No keyboard or global mouse events are monitored. State assignments are skipped when already correct. The timer stops when rendering is hidden or the display sleeps.

Progress redraws twice per second during compact playback and once per second when expanded. There is no periodic progress TimelineView while paused or rendering is disabled. Expanded elapsed seconds update once per second only during playback.

Spotify's `com.spotify.client.PlaybackStateChanged` notification, found in the installed binary, triggers opportunistic synchronization. This is not a compatibility contract: a fallback timer with one-second tolerance synchronizes every 10 seconds while playing and every 30 seconds while paused. When Spotify is closed, launch notifications replace polling. Periodic tasks stop when the contour is hidden, the display sleeps or no notched screen is available.

AppleScript scripts are reused and unchanged observable properties are not reassigned. Calls remain on the main thread with a one-second timeout. Spotify duration is interpreted as milliseconds; the installed dictionary described seconds, which still requires an independent comparison.

Artwork downloads use an ephemeral session without URL caching. ImageIO downsamples off the main thread to at most 128 pixels before NSImage conversion. Only the current thumbnail is retained; previous downloads are canceled when artwork changes. The settings window and its SwiftUI hierarchy are released on close.

## Preferences and distribution

The user requested an optional automatic start with the system. The waveform menu now exposes “Démarrer avec le système”, implemented with `SMAppService.mainApp` (macOS 13+). It launches at user login, without a helper or custom LaunchAgent. Nothing is registered on application startup: registration and removal happen only through the menu action. The menu reads the current system status whenever opened, shows a mixed state for pending approval, offers Login Items settings when approval is needed, and reports API errors. macOS owns this preference; no duplicate UserDefaults flag is stored. This does not change Spotify integration or screen placement. Registration API: [Apple documentation](https://developer.apple.com/documentation/servicemanagement/smappservice).

Preferences domain: `local.notchmusique.app`. UserDefaults persists color and thickness. The old `contour.margin` value is ignored. No listening history, OAuth tokens or analytics are added.

The build uses available Command Line Tools without changing the system Xcode selection or accepting licenses. Signing is ad hoc, without a distribution certificate or notarization. Public distribution changes require explicit consideration.

## Release packaging request — November 13, 2026

The user requested a binary package for a GitHub release. [The packaging script](../package-release.sh) builds and checks a versioned ZIP and SHA-256 checksum under `build/release/`. It verifies the extracted app before completing. See [release instructions](RELEASE.md). This prepares local upload artifacts; it does not publish a release, add a distribution certificate, notarize the app or accept licenses.

## Screenshots

The French UI command “Exporter des captures…” lets users choose a folder and export actual application views through AppKit's drawing cache: `contour.png`, `lecteur.png`, `apparence.png`. It does not capture other desktop windows or simulate playback input. Playback state and settings visibility are restored afterward. Documentation is English; existing UI labels and screenshot filenames retain their original language.

## References

- [NSTrackingArea](https://developer.apple.com/documentation/appkit/nstrackingarea).
- [Mouse event monitoring](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html).
- [Display sleep notification](https://developer.apple.com/documentation/appkit/nsworkspace/screensdidsleepnotification).
- [ImageIO downsampling, WWDC 2018](https://devstreaming-cdn.apple.com/videos/wwdc/2018/219mybpx95zm9x/219/219_image_and_graphics_best_practices.pdf).
- Installed Spotify application's AppleScript dictionary and playback change signal.
