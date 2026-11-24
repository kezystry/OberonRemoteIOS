# Oberon Remote iOS — native iPhone input-server prototype

This is an independent native SwiftUI iOS project intended to let an iPhone act as the **Oberon input server**. The Xbox remains the WebSocket client and enters the iPhone's local Wi-Fi IPv4 address in the original Oberon Xbox app.

## DualSense support

The app uses Apple's `GameController` framework and explicitly recognizes the `GCDualSenseGamepad` profile. The mappings follow Apple's DualSense profile guidance:

| DualSense control | iOS GameController element | Oberon / Xbox input |
|---|---|---|
| Cross (✕) | `buttonA` | A |
| Circle (○) | `buttonB` | B |
| Square (□) | `buttonX` | X |
| Triangle (△) | `buttonY` | Y |
| L1 / R1 | `leftShoulder` / `rightShoulder` | LB / RB |
| L2 / R2 | `leftTrigger` / `rightTrigger` | LT / RT (analog) |
| L3 / R3 | `leftThumbstickButton` / `rightThumbstickButton` | L3 / R3 |
| D-pad | `dpad` directions | D-pad |
| Options | `buttonMenu` | Menu / Start |
| Create | `buttonOptions` | View / Back |
| Touchpad click | `GCDualSenseGamepad.touchpadButton` | View / Back |
| PS button | `buttonHome` | Xbox Guide |
| Both sticks | `leftThumbstick` / `rightThumbstick` | Left / right analog sticks |

The app asks iOS to disable the system gesture on the controller's PS button so it can forward that input as the Xbox Guide button. Apple notes this preference is not guaranteed in every system-gesture situation. It also explicitly starts Apple's wireless controller discovery from the **Find controller** button. Pairing still happens in iOS Bluetooth Settings.

### Pairing

1. On the DualSense, hold **PS + Create** until the light bar flashes.
2. Open iPhone **Settings → Bluetooth** and select **DualSense Wireless Controller**.
3. Return to this app and tap **Find controller**.
4. The app should identify it as **Sony DualSense** and show `DualSense profile detected`.

## What is implemented

- Native SwiftUI interface with the phone's Wi-Fi IPv4 address and port `26401`.
- Local WebSocket listener using Apple's Network framework.
- Oberon handshake: binary message `[0x0A] + UTF-8 device name` after a WebSocket client connects.
- Oberon request handling: binary request beginning with `0xFA`; the server responds with a 100-byte controller-state packet.
- One active physical extended-gamepad profile, prioritizing DualSense if more than one controller is connected.
- Analog sticks, analog triggers, face buttons, shoulders, menu, Create/Share, guide, thumbstick clicks and D-pad.
- DualSense/DualShock clickable touchpad mapped to Xbox View/Back.
- The IP is refreshed when the server becomes ready and when the app returns to the foreground.
- A shared Xcode scheme and a GitHub Actions workflow that builds and packages an unsigned IPA.

## Known limitations and validation status

- **Not yet built with Xcode or tested on a physical iPhone/Xbox.** This environment does not include Apple's Xcode/iOS SDK, so a successful iOS compile cannot be claimed here.
- Rumble feedback from Xbox is not yet sent back to the DualSense. All regular controller input is forwarded; vibration is currently input-only/unimplemented.
- Only one physical controller is forwarded (slot 1). The packet format reserves four slots.
- The iPhone app must remain open and active while playing. The server is stopped when the app enters the background; iOS does not provide a general-purpose background game-controller input service for this app.
- iPhone and Xbox must be on the same local network. Guest Wi-Fi, client isolation, VPN routing, or different VLANs can block the connection.
- The original Oberon protocol has no authentication. This server accepts local WebSocket clients on port `26401`, so run it only on a trusted network.
- If the IP shows `No Wi-Fi IPv4`, connect the iPhone to the same Wi-Fi network as the Xbox and refresh/restart the server.

## Build with Xcode

1. Open `OberonRemoteIOS.xcodeproj` on a Mac with Xcode.
2. Select the shared `OberonRemoteIOS` scheme and an iPhone destination.
3. In **Signing & Capabilities**, choose your Apple Development team and set a unique bundle identifier if you need a normal Xcode installation.
4. Build and run on the iPhone.
5. Pair the DualSense using the steps above.
6. Allow Local Network access when iOS prompts you.
7. Tap **Start input server**.
8. On Xbox, open Oberon Remote Input, add a remote and enter the IP address shown by the iPhone app. Oberon uses port `26401` by default.

## Build an unsigned IPA from Windows using GitHub Actions

You do not need to run `adro0303/ipa-builder` for this project. That repository's [published workflow](https://github.com/adro0303/ipa-builder/blob/main/.github/workflows/build-ipa.yml) is built around Expo/React Native: it requires a `package.json` and `app.json`, runs `npm install`, `npx expo prebuild`, and CocoaPods. This is a native SwiftUI/Xcode project, so that workflow is not directly compatible without replacing its build steps. This project already includes a native Xcode workflow, so you do not need to fork `ipa-builder` or create its cross-repository token.

This repository includes a matching Xcode workflow at `.github/workflows/build-unsigned-ipa.yml`:

1. Push this entire project folder to a GitHub repository.
2. Open its **Actions** tab.
3. Choose **Build unsigned iOS IPA** → **Run workflow**.
4. Download the `OberonRemoteIOS-unsigned-ipa` artifact from the completed run.
5. Use Sideloadly on Windows to sign/install the IPA with your Apple ID. A free Apple ID generally requires periodic re-signing.

The workflow uses a GitHub-hosted macOS runner and `xcodebuild`; the IPA is unsigned and does not contain your Apple signing certificate or provisioning profile.

## Protocol notes

The implementation follows the public Oberon source's Xbox-side `SocketClient` and `InputForwarder` behavior:

- WebSocket server port: `26401`.
- On WebSocket open, send a binary handshake beginning with `0x0A`, followed by a UTF-8 device name.
- The Xbox sends binary requests beginning with `0xFA` and normally includes 16 rumble bytes (17 bytes total).
- The server replies with 100 bytes: four 25-byte controller slots. A populated slot starts with `0xFF`; axes and triggers are little-endian signed 16-bit values; buttons are stored in two bitmasks.

## Source references

- Original project and Xbox receiver: https://github.com/SamsidParty/OberonRemote
- Apple's DualSense controller profile: https://developer.apple.com/documentation/gamecontroller/gcdualsensegamepad
- Apple's controller profile mapping guide: https://github.com/apple/game-porting-toolkit/blob/main/game-porting-skills/skills/using-game-controller/reference/profile-based-input.md
