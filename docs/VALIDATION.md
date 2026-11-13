# Validation

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
