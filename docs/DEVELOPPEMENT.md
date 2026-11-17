# Development and handoff

Status: November 13, 2026. Sources: user requests, source code and local checks. This project is self-contained; neighboring files are not required.

## Confirmed requirements

MacBook Air M5, Spotify desktop, and a discreet contour around the physical notch. On hover, the contour itself expands to contain playback information. Color and thickness are customizable; compact dimensions follow stroke thickness with one point of technical padding. The README should be humorous, centered and illustrated with a logo, emojis and screenshots. The user subsequently requested English documentation for an international audience.

## Compact utility direction — November 13, 2026

Confirmed user feedback: BOnotch's **expanded panel** feels too large on the user's 13-inch screen. The user explicitly clarified that the closed notch's size is satisfactory and likes the artwork displayed at rest. The functions to retain are media, calendar and a focus timer, including clear identification of the current activity during focus. Other inconveniences have not yet been specified.

Observed in BOnotch's settings: a collapsed activity priority (Focus → Meeting → Media), a 25-minute work / 5-minute break timer, and calendar integration described as reading accounts already configured in macOS. These are observations of BOnotch, not implemented or validated Notch Musique features.

The user subsequently requested implementation of Media, Calendar and Focus in Notch Musique, with a default 25-minute focus / 5-minute break cycle, skipping to the next phase, and alternative durations. These utilities are now implemented. Spotify desktop remains the selected and only implemented media source; no universal playback API is assumed.

Inspection: BOnotch 1.4 (build 6) was relaunched with user authorization. The user manually opened the panel because automated pointer interactions could not reproduce hover expansion. Media, Calendar and Focus were then inspected through their tabs. No physical panel dimensions were measured; screenshots alone are not a screen-geometry validation.

- Closed media: artwork on the left and a playback indicator on the right. Its size is acceptable to the user.
- Expanded media: large artwork, title/artist/status, transport controls and a long seek bar. This arrangement offers opportunities to reduce artwork size, spacing and panel width.
- Focus: a prominent phase label and countdown, work/break presets (25/5, 50/10, 15/5), and Start. Running state exposes Pause, Skip and Reset. The closed running view shows a purple timer icon and remaining time. This visually identifies the active utility; no user-defined task-name field was observed. A temporary session was started for inspection, then Reset was used and the idle 25:00 / Start state was verified.
- Calendar: an upcoming-events list next to a reminders column. The reminders column remained empty in the observed state, consuming substantial space. Proposal: prioritize a single compact upcoming-events list, with reminders shown only when relevant or requested. No event was opened or edited; no personal event content is recorded here.

Implemented compact expanded layout: three small tabs; 38-point media artwork beside metadata, transport controls and a seek slider committed on drag completion (direct keyboard/accessibility value changes commit immediately); focus phase and a 26-point countdown with controls on one row; calendar as a short scrolling list. A pin button keeps the panel open; the waveform and native application menus also offer “Ouvrir le panneau…” for direct access without hover. Calendar connection pins the panel before the system permission prompt.

Focus alternates automatically between work and break, with Pause/Resume, Skip and Reset. Presets are 15/5, 25/5 and 50/10; “Durées…” offers separate work and break durations. Changes require resetting an active session. Selected durations persist locally; an in-progress session does not survive quitting. Deadlines use wall-clock time, so hidden/display-sleep periods count toward the phase. Full cycles missed during sleep are skipped arithmetically. The display timer stops while hidden or asleep and catches up on return. A system beep signals a phase change while visible. The idle glance prioritizes an active or paused focus, then an ongoing or imminent timed calendar event (within 15 minutes), then Spotify. Focus uses a timer or cup icon and remaining time; pausing freezes it. Progress follows the active focus when a session exists, otherwise Spotify.

Calendar uses EventKit for the next seven days (up to 50 events), including ongoing events, excluding canceled and personally declined events. It is a single read-only list with all-day and local-time labels. It reads calendars configured in macOS; separate Google/Outlook apps or websites are not data providers. It never writes events, reads reminders, or requests access on launch. The explicit connect button uses full event access on macOS 14+ and the legacy permission API on macOS 13. Both purpose strings are present. macOS permission covers more than read-only access, but the application only fetches. Denial/restriction and failure have dedicated UI states. Store changes, activation and a visible one-minute fallback refresh the list. EventKit fetches use a serial background queue and only value snapshots reach the UI; stale results are discarded. Calendar content is not persisted or logged. Demo mode uses a clearly fictional event and does not initialize an event store.

See [validation](VALIDATION.md) for checks and remaining manual validation.

## Architecture

- `Sources/main.swift`: Dockless AppKit application, transparent window, placement, event-based pointer tracking, menus, settings and screenshot export.
- `Sources/NotchView.swift`: SwiftUI views, contour, progress and expansion.
- `Sources/Spotify.swift`: reused AppleScript scripts, metadata, position interpolation, controls and thumbnails.
- `Sources/Appearance.swift`: local preferences and appearance window.
- `Sources/Focus.swift`: focus/break deadlines, cycle transitions and saved durations.
- `Sources/Calendar.swift`: opt-in EventKit access and agenda snapshots.
- `Sources/UtilityTests.swift`: deterministic focus and geometry assertions.
- `Resources/Info.plist`: identity, version and automation permission message.
- `build.sh`: optimized arm64 compilation and ad hoc signing.

## Implementation decisions

Notch geometry comes from `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`. No Mac model is hard-coded. Screens without a notch retain only the menu.

Progress follows an open path: left edge → rounded bottom → right edge. Compact width is physical width + twice (54-point activity wing + thickness + 1); compact height is physical height + thickness + 1. The physical camera width stays empty between the wings. Expanded width is normally 360 points (at least the closed width), capped by the distance to both actual screen edges. Height is compact height + 166 points for Media/Focus or + 198 for Calendar, capped by screen height minus 24 points. SwiftUI uses a damped spring, a 280 ms collapse delay, and final window resizing after collapse completes. A pinned panel stays open; unpinning restores hover collapse. Screens without a physical notch still show only the menu.

## Optimization

Native and SwiftUI hover events are backed by a 250 ms check (80 ms in the prototype). Events alone were insufficient during automated testing, so the fallback remains. No keyboard or global mouse events are monitored. State assignments are skipped when already correct. The timer stops when rendering is hidden or the display sleeps.

Progress redraws twice per second during compact playback and once per second when expanded. There is no periodic progress TimelineView while paused or rendering is disabled. Expanded elapsed seconds update once per second only during playback.

Spotify's `com.spotify.client.PlaybackStateChanged` notification, found in the installed binary, triggers opportunistic synchronization. This is not a compatibility contract: a fallback timer with one-second tolerance synchronizes every 10 seconds while playing and every 30 seconds while paused. When Spotify is closed, launch notifications replace polling. Periodic tasks stop when the contour is hidden, the display sleeps or no notched screen is available.

AppleScript scripts are reused and unchanged observable properties are not reassigned. Calls remain on the main thread with a one-second timeout. Spotify duration is interpreted as milliseconds; the installed dictionary described seconds, which still requires an independent comparison.

Artwork downloads use an ephemeral session without URL caching. ImageIO downsamples off the main thread to at most 128 pixels before NSImage conversion. Only the current thumbnail is retained; previous downloads are canceled when artwork changes. The settings window and its SwiftUI hierarchy are released on close.

## Preferences and distribution

The user requested an application icon. The existing project logo is packaged as [AppIcon.icns](../Resources/AppIcon.icns), referenced by `CFBundleIconFile` and copied into the bundle before signing. Regenerate its standard and Retina representations with `bash generate-icon.sh`; see [branding](../assets/LOGO.md). This changes the bundle identity artwork, without modifying Spotify integration or screen geometry.

The user requested an optional automatic start with the system. The waveform menu now exposes “Démarrer avec le système”, implemented with `SMAppService.mainApp` (macOS 13+). It launches at user login, without a helper or custom LaunchAgent. Nothing is registered on application startup: registration and removal happen only through the menu action. The menu reads the current system status whenever opened, shows a mixed state for pending approval, offers Login Items settings when approval is needed, and reports API errors. macOS owns this preference; no duplicate UserDefaults flag is stored. This does not change Spotify integration or screen placement. Registration API: [Apple documentation](https://developer.apple.com/documentation/servicemanagement/smappservice).

Preferences domain: `local.notchmusique.app`. UserDefaults persists color, thickness and focus durations. The old `contour.margin` value is ignored. No listening history, OAuth tokens or analytics are added.

The build uses available Command Line Tools without changing the system Xcode selection or accepting licenses. Signing is ad hoc, without a distribution certificate or notarization. Public distribution changes require explicit consideration.

## Release packaging request — November 13, 2026

The user requested a binary package for a GitHub release. [The packaging script](../package-release.sh) builds and checks a versioned ZIP and SHA-256 checksum under `build/release/`. It verifies the extracted app before completing. See [release instructions](RELEASE.md). This prepares local upload artifacts; it does not publish a release, add a distribution certificate, notarize the app or accept licenses.

## Screenshots

The French UI command “Exporter des captures…” lets users choose a folder and export actual application views through AppKit's drawing cache: `contour.png`, `lecteur.png`, `apparence.png`. It does not capture other desktop windows or simulate playback input. Playback state and settings visibility are restored afterward. Documentation is English; existing UI labels and screenshot filenames retain their original language.

## References

- [EventKit access levels](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels).
- [EventKit fetching](https://developer.apple.com/documentation/eventkit/retrieving-events-and-reminders).
- [Calendar change notifications](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/ekeventstorechanged).

- [NSTrackingArea](https://developer.apple.com/documentation/appkit/nstrackingarea).
- [Mouse event monitoring](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html).
- [Display sleep notification](https://developer.apple.com/documentation/appkit/nsworkspace/screensdidsleepnotification).
- [ImageIO downsampling, WWDC 2018](https://devstreaming-cdn.apple.com/videos/wwdc/2018/219mybpx95zm9x/219/219_image_and_graphics_best_practices.pdf).
- Installed Spotify application's AppleScript dictionary and playback change signal.

## Idle countdown — November 18, 2026

**Distribution decision:** the user is considering publication as a general countdown feature. Use neutral examples in UI placeholders, demos, tests and documentation; keep personal names out of distributable project content. Publication remains undecided. No push, release or new release package has been requested or performed.

Confirmed request: show a countdown when no music is playing, with a manually entered short label (for example an upcoming holiday), a target date/time, and weeks/days/hours remaining. Implemented in `Sources/Countdown.swift` and the hourglass tab. No personal deadline was assumed or saved during development.

The saved Codable target contains a trimmed label of up to 40 characters and an absolute Date in UserDefaults (`countdown.target`). Save validates a nonblank label; the editor requires a future date. Persisted elapsed targets stay visible with an arrived message until removed. The media tab substitutes the countdown summary while idle. Closed priority is unchanged for Focus and imminent meetings, followed by playing Spotify, then the configured countdown, then idle media. Spotify desktop remains the only supported music source: playback in other apps cannot suppress the countdown.

The compact countdown uses two lines inside the existing 54-point right wing and a heart in the left wing, without changing camera clearance. The fourth tab uses an hourglass icon to retain the 360-point panel width. The editor adds 218 points below the physical notch and respects screen bounds. Its fields pin the panel; `NotchPanel` now permits becoming key so text and date input can work in the nonactivating panel. Countdown clocks use visible-only one-second TimelineViews; remaining time is derived from the deadline, without a background countdown timer. Demo targets use nonpersistent storage. Native demo preview mode may run alongside the regular app solely to export renders without stopping playback.

See [validation](VALIDATION.md) for actual checks and limitations.
