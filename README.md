# Oberon Remote iOS prototype

Native SwiftUI iPhone app prototype that acts as an Oberon-compatible WebSocket input server for Xbox.

- App project: [`iOS/`](iOS/)
- Setup, DualSense pairing, limitations and protocol notes: [`iOS/README.md`](iOS/README.md)
- Unsigned IPA GitHub Actions workflow: [`.github/workflows/build-unsigned-ipa.yml`](.github/workflows/build-unsigned-ipa.yml)

## Build an unsigned IPA

Push this repository to GitHub, open **Actions**, choose **Build unsigned iOS IPA**, and select **Run workflow**. Download the `OberonRemoteIOS-unsigned-ipa` artifact when the workflow completes. The IPA still needs to be signed before installing it on an iPhone.

## Validation status

The standalone Oberon packet protocol test and static project checks passed in the preparation environment. The app has not yet been built with Xcode or tested on a physical iPhone and Xbox. See [`iOS/REVIEW_REPORT.md`](iOS/REVIEW_REPORT.md).
