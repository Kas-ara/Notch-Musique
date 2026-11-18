# 🤝 Contributing

Thanks for giving this notch a little love.

## Getting started

You need an Apple Silicon Mac, macOS 13 or later, and Apple's Command Line Tools. No external packages are required.

```sh
bash build.sh
'build/Notch multitools.app/Contents/MacOS/NotchMultitools' --self-test
open 'build/Notch multitools.app' --args --demo
```

Quit any existing instance before relaunching. To test real Spotify playback, quit demo mode and launch normally.

## Proposing a change

- Describe the concrete problem and expected behavior.
- Keep the interface discreet and preserve the same contour during expansion.
- Keep compact dimensions tied only to stroke thickness.
- Prefer hover events, retain a slow fallback when necessary, and avoid unnecessary redraws while paused.
- Report checks actually performed and remaining limitations.
- Include a screenshot when changing the appearance.

User-facing strings live in the matching French and English tables under Resources. Update both Localizable.strings files when adding an interface label and both InfoPlist.strings files when changing permission descriptions.

Code lives in `Sources/`, the build script in `build.sh`, resources in `Resources/`, and visuals in `assets/`. See [validation results](docs/VALIDATION.md).

Do not include tokens, personal files, account data, local preferences or compiled binaries. Git ignores `build/`.

Contributions are offered under the project's [MIT license](LICENSE). The logo was generated with imagegen; its prompt is documented in [assets/LOGO.md](assets/LOGO.md).
