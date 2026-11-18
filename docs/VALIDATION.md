# Validation

## Notch multitools and localization — November 18, 2026

The renamed arm64 application built successfully and passed 47 headless assertions in French, English, with French as the second macOS language preference, and with English as the fallback for German. The checks cover the translated tab names, countdown units in both display sizes, calendar accessibility text and localized permission descriptions read by the app. Both language tables contain the same 92 interface keys and three permission descriptions.

The bundle identifier matches the previous build. Packaging the 0.5.0 arm64 bundle verified the signatures of the built and extracted app, reran the self-tests and verified the ZIP's SHA-256 checksum.

Visual inspection in both languages, switching the language through System Settings, and the actual macOS permission dialogs and login item migration remain to be checked.

## Idle countdown — November 18, 2026

`bash build.sh` completed, then `'build/Notch Musique.app/Contents/MacOS/NotchMusique' --self-test` passed **43 assertions**. Twelve new checks cover initial absence, blank and bounded labels, weeks/days/hours/minutes decomposition, Spotify/focus/meeting priority, subminute rounding, exact and overdue deadlines, persisted restart/deletion behavior, and editor geometry. Tests use injected dates and an isolated temporary UserDefaults suite, without modifying the user's countdown. The existing simulated Spotify, image, seek, focus and geometry checks still pass.

Actual `--screen-info` query: Built-in Retina Display, 1470 × 956 points, safe top inset 32 points, camera x=645.5…824.5 (179 points). Native demo renders were exported with this geometry and visually inspected for the editor, expanded idle summary and closed countdown. The two-line time stays in the right activity wing outside the camera; the label, date/time field, save/delete controls and four tabs fit the 360-point panel. The editor is approximately 253 points high and the idle summary approximately 201 points high. The fictional demo target was held only in nonpersistent storage. Examples were subsequently made neutral throughout the UI, demo, tests and documentation; the layout is unchanged. The regular running app was not stopped or replaced.

These checks validate deterministic behavior and rendered layout. Live keyboard entry, date-field editing, save/delete clicks, real Spotify pause/resume switching with a configured countdown, sleep/wake, time-zone/DST changes and alternate hardware have not been manually exercised for this feature. No new calendar authorization or playback control was performed. Deadline calculations use absolute elapsed time; remaining minutes round up and stop at the arrived state. The countdown has no notification or alarm. Visible-only one-second clocks are implemented; their CPU/battery cost was not measured. Relaunch the built app to use the new version.


## Local release package 0.4.0 — November 13, 2026

The user requested local tagging and packaging, with a local commit if needed. `bash package-release.sh` completed successfully: it ran `bash build.sh`, then the correctly quoted executable with `--self-test` (31 assertions passed), verified the ad hoc signature, created the ZIP, extracted it, verified the extracted signature, reran all 31 assertions successfully, and generated and verified the SHA-256 checksum. Shell syntax, Info.plist lint and `git diff --check` also passed. See [release files and notes](RELEASE.md).

This packages the implemented features and application icon. It adds no new manual calendar, Spotify or display validation beyond the observations below. The application remains ad hoc signed and not notarized; downloaded-app Gatekeeper approval is unvalidated. The requested release commit and annotated `v0.4.0` tag are local; the ZIP and checksum remain under ignored `build/release/`.

## Application icon — November 13, 2026

The user requested an application icon. The existing [project logo](../assets/logo.png) was packaged into [AppIcon.icns](../Resources/AppIcon.icns), with standard and Retina representations from 16 to 1024 pixels. The converted PNG preview was visually inspected. Icon conversion failed inside the restricted environment despite valid PNG sizes, then succeeded using macOS `iconutil` outside it with approval.

`bash build.sh` completed successfully, then `'build/Notch Musique.app/Contents/MacOS/NotchMusique' --self-test` passed all 31 assertions. The built plist references `AppIcon.icns`; the bundled file matches the source byte for byte. Ad hoc signature verification, plist lint, icon script shell syntax and `git diff --check` passed. This checks bundle packaging, not Finder/Launch Services cache refresh. The running app was not restarted for this icon-only change. Spotify integration and screen geometry were unchanged; no new manual media or display validation was performed.

## Compact utilities — November 13, 2026 (0.4.0)

Confirmed implementation request: Media, Calendar and Focus, with artwork at rest, a smaller expanded panel, automatic 25/5 focus/break cycles, skip and alternative durations. The user clarified that BOnotch's closed size was satisfactory; its expanded interface was the issue. See [development decisions](DEVELOPPEMENT.md).

`bash build.sh` and the correctly quoted executable with `--self-test` passed. The suite now has **31 assertions**: the original ten Spotify/image checks, three simulated seek/bounds checks, and eighteen focus/geometry checks. Focus checks cover exact phase boundaries, late callbacks, pause/resume, skip while running and paused, return from a long hidden interval, preset changes and duration bounds. Geometry checks cover camera clearance and panel bounds. Tests do not request calendar access or contact Spotify. Shell syntax, Info.plist lint, ad hoc signature verification and `git diff --check` also passed.

Actual display query: Built-in Retina Display, 1470 × 956 points, safe top inset 32 points, camera x=645.5…824.5 (179 points). Native render review used this geometry. Media/Focus measure 360 × approximately 201 points; Calendar 360 × approximately 233 points, with the current 1.6-point stroke preference. Activity wings remain outside the measured camera interval. Screens without a notch remain unsupported for the overlay. Alternate screen bounds are covered by assertions, not by external-display hardware tests.

Native Computer Use checks on the built app:

- Real Spotify artwork, track metadata and playback position appeared both closed and expanded.
- Pause changed the control to Play, and resuming restored Pause. A real seek through the slider's accessibility value moved paused playback to the middle of the track; the original position was restored, then playback resumed. Real previous/next and pointer-drag seeking remain to be manually validated; simulated seek and clamping pass.
- Direct panel opening pins it. Tabs switch between Media, Calendar and Focus and resize the panel.
- Focus Start, running Skip to a 5-minute break, Pause, paused Skip back to a 25-minute focus, Resume and Reset all produced the expected visible states. The 50/10 preset showed 50:00; 25/5 was restored and the timer was left idle. Duration choices were inspected. Automatic transitions and long-sleep catch-up were validated with injected dates, not by waiting through full live cycles or sleeping the hardware.
- Calendar initially showed its explicit connect button. No calendar access was granted during validation. Real authorized fetching, denied/restricted states, account changes, all-day/time-zone behavior and background EventKit updates still require manual validation. The seven-day list was visually inspected using a clearly fictional demo event; it does not validate a user's calendar accounts.
- Native screenshot export refreshed the real Spotify and appearance screenshots without capturing other windows and restored the selected Calendar tab. Focus and Calendar documentation screenshots come from demo renders. Full redraw was added before bitmap capture to avoid incomplete cached SwiftUI content.

No new CPU/RAM or battery measurements were taken. The historical music-only measurements below do not establish the cost of focus or calendar. Hover, display sleep/wake, fullscreen and external displays still need broader manual checks. Calendar reading uses public EventKit; media remains Spotify desktop only. No license, login-item setting or calendar permission was accepted on the user's behalf.

For repeatable native demo rendering, quit the running app and run the following from a graphical session (the command exits after writing six PNGs; it does not contact Spotify or read real calendars):

```sh
'build/Notch Musique.app/Contents/MacOS/NotchMusique' --demo --preview-output /tmp/notch-musique-previews
```

`--screen-info` prints actual NSScreen geometry without starting playback or calendar integration. GUI/display access is required for both diagnostic commands. The self-test remains headless.

## Release archive — November 13, 2026

`bash package-release.sh` completed successfully for version 0.3.0. It ran `bash build.sh`, then the correctly quoted executable with `--self-test`: all ten assertions passed. Ad hoc signature verification passed for both the build and the extracted ZIP. The extracted app also passed all ten assertions, and the generated SHA-256 checksum verified successfully. Artifacts are described in [release packaging](RELEASE.md).

These checks do not validate GitHub publication, downloaded-app Gatekeeper approval, Spotify playback, actual screen geometry or launch at login. Source compatibility remains Spotify desktop, arm64 and macOS 13+, with a notched display required for the contour; no media integration or geometry code changed.

Date: November 13, 2026. Sources: local commands, code and application inspection with Computer Use. Observed environment: Apple Silicon Mac, macOS 27.0.1; Swift 6.4.2 in Swift 5 mode, targeting macOS 13 arm64.

## Automated checks

- Optimized arm64 build and ad hoc signature verified.
- Ten assertions cover initial progress, upper/lower bounds, pause, frozen position while paused, resume, duration formatting, PNG fixture creation, proportional downsampling to 128 pixels, and invalid image rejection.
- These assertions do not exercise Spotify, automation or networking.

## Previously observed native behavior

- Compact contour around the actual notch.
- Expanded player with real Spotify title, artist, artwork and elapsed time; return to compact state.
- Color and thickness settings persisted after relaunch.
- User feedback led to compact dimensions depending only on thickness, removing independent overflow.

## Performance observations

Spot readings in Activity Monitor with the compact contour and Spotify open. These are not controlled benchmarks and establish no battery-life claim.

| Version | Observed CPU | Idle wakeups |
| --- | --- | --- |
| Before optimization | 3.19–4.0% | 73 in the initial reading |
| First optimized version | 0.3% in an initial reading | 8 in the same reading |
| Version with hover fallback, after settling | 0.4% | 7 in the same reading |

The first memory reading returned zero bytes. A later optimized-process reading showed 32.8 MB. After settings and screenshot export, it showed 45.8 MB, with separate auxiliary system processes. No overall RAM reduction is established. Retained artwork is bounded to a 128-pixel thumbnail; AppKit/SwiftUI remain loaded. Releasing the settings window on close was added afterward; its individual benefit was not measured.

The final application was rebuilt and relaunched locally. All three README screenshots were exported from native views and inspected: compact contour, player with a real Spotify track, and settings on an opaque background. Signing and ten assertions passed after compilation. Export temporarily forces expanded/collapsed states and does not independently validate hover activation.

Synthetic hover did not confirm activation. The user later explicitly confirmed that it opens normally with their mouse on the optimized version. The tool also observed real Spotify metadata in the expanded player after the final relaunch. Animation smoothness was not instrumented.

## Still to validate

- Perceived expansion smoothness on other configurations; hover was confirmed by the user on their machine.
- Spotify pause/resume and track changes. An earlier automated click failed on a stale accessibility identifier and does not count as validation.
- External displays, fullscreen, sleep/wake and prolonged hiding.
- Duration units, synchronization after seeking and notifications across Spotify versions.
- Consumption over several hours, while paused and with mouse activity; controlled before/after RAM comparison.

The deployment target alone does not certify earlier macOS versions or other hardware.

## Launch at login option — November 13, 2026

After adding the ServiceManagement menu action, `bash build.sh` completed successfully, including ad hoc signing. Running `'build/Notch Musique.app/Contents/MacOS/NotchMusique' --self-test` passed all ten existing assertions. These checks do not register a login item or validate automatic launch. Registration, removal, pending approval, error presentation, external changes in System Settings, and launch after signing out and back in still require manual validation. No login item was enabled during these checks. Spotify and screen geometry code were unchanged; no additional manual playback or display validation was performed.

## English documentation update — November 13, 2026

After translating the documentation, `bash build.sh` completed successfully and the correctly quoted executable path with `--self-test` passed all ten assertions. This documentation change does not add new manual Spotify or screen-geometry validation.
