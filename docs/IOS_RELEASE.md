# BSCI iOS build and release

The project is configured for iPhone and iPad with:

- app name: `BSCI`
- bundle identifier: `com.bscibd.bsciapp`
- minimum iOS version: 15.0
- custom deep-link scheme: `bsci://`
- universal-link domain: `https://bsci.digitrixlabs.io`
- Flutter Swift Package Manager integration for native plugins

## Simulator validation without an Apple Developer account

Run the `ios-simulator` workflow from `codemagic.yaml`, or use a Mac:

```sh
flutter config --enable-swift-package-manager
flutter pub get
flutter analyze
flutter test
flutter build ios --simulator --release
```

The simulator artifact is generated at:

```text
build/ios/iphonesimulator/Runner.app
```

## Physical iPhone, TestFlight, and App Store

Before producing a signed IPA:

1. Enroll the organization in the Apple Developer Program.
2. Register the bundle identifier `com.bscibd.bsciapp`.
3. Enable Associated Domains for the App ID.
4. Configure automatic signing in Xcode or the CI signing integration.
5. Set a unique build number for every upload.
6. Build with `flutter build ipa --release` on macOS.

## Universal-link activation

After Apple supplies the Team ID, publish an Apple App Site Association file at:

```text
https://bsci.digitrixlabs.io/.well-known/apple-app-site-association
```

Its application identifier must use `<APPLE_TEAM_ID>.com.bscibd.bsciapp`.
The custom `bsci://` scheme works independently of this server file.

## App Store information still required from the owner

- Apple Developer Team ID and signing credentials
- App Store Connect app record
- support URL and privacy-policy URL
- final screenshots from required iPhone/iPad sizes
- privacy questionnaire and age rating
