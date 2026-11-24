# Pre-test review report

## Corrections made

1. **DualSense Create input was not described precisely enough.** The revised code explicitly recognizes `GCDualSenseGamepad`; Apple maps its `buttonMenu` to Options, `buttonOptions` to Create, and `buttonHome` to PS. The app maps those to Oberon Menu, View and Guide respectively.
2. **DualSense touchpad click was missing.** It now also maps to Oberon View/Back, matching Apple's controller-porting reference guidance. DualShock 4 touchpad click is supported by the same mapping.
3. **The PS button could be intercepted by an iOS system gesture.** The app now sets the controller Home/PS element's `preferredSystemGestureState` to `.disabled` so it can forward that input as Xbox Guide.
4. **Wireless controller discovery was missing.** The Find Controller button now calls `GCController.startWirelessControllerDiscovery`; the app stops discovery after a controller connects or when the app backgrounds.
5. **Controller event handling added unnecessary actor hops.** The input callback is explicitly assigned to the main queue, and the handler updates the synchronized packet directly instead of scheduling a new task for every small input event.
6. **DualSense selection is prioritized.** If iOS reports multiple extended gamepads, a DualSense remains preferred over another non-Sony controller.
7. **Wi-Fi address refresh was incomplete.** The address is refreshed once the listener is ready and when the app returns to the foreground; interface lookup prefers `en0` and has an `en*` fallback.
8. **The original Xcode workflow lacked a shared scheme.** A shared `OberonRemoteIOS` scheme is now included so command-line `xcodebuild -scheme OberonRemoteIOS` has a repository-visible scheme to select.
9. **The build workflow was made more defensive.** It checks the scheme, runs the protocol test, verifies that the `.app` bundle exists, and then packages `Payload/OberonRemoteIOS.app` into the IPA.
10. **Packet size is guarded.** The server always replies with exactly 100 bytes; if a future provider returns a different size, it sends a neutral 100-byte packet instead.
11. **The display no longer stays awake when idle.** The idle timer is disabled only while the server is actually running, and is re-enabled on backgrounding/stopping.
12. **The no-authentication limitation is made explicit.** The app warns that the Oberon protocol has no authentication and should only be run on a trusted local network.
13. **The protocol test now checks the actual handshake and Xbox request shape.** It verifies `0x0A + UTF-8 name`, an expected 17-byte `0xFA` request, ignores empty/other frames, and tests both DualSense View inputs individually and together.
14. **The request counter is throttled.** The server no longer schedules one main-thread UI update for every Xbox polling request; it publishes the display counter at most four times per second while keeping packet replies on the networking queue.
15. **The default bundle identifier is no longer the Xcode example ID.** It now uses `com.oberonremote.iosinput`; users can still change this to their own unique identifier before signing.
16. **Wi-Fi address selection rejects self-assigned/link-local addresses.** An `en0` address such as `169.254.x.x` is not advertised as a usable Xbox route.

## Static checks run in this environment

- Swift syntax parse of all app source files: passed.
- Protocol implementation compiled with Swift 6.2.1 on Linux: passed.
- Protocol tests: passed for the exact pairing handshake, 17-byte Xbox input-request recognition, ignored empty/non-request frames, 100-byte neutral/active responses, byte order, stick-axis orientation, analog trigger ranges, all mapped button bits, inactive slots, and Create/touchpad View mapping (including both pressed together).
- `Info.plist` and Xcode project syntax validation: passed.
- Shared Xcode scheme XML parsing: passed.

## Checks not possible here

- No Xcode or Apple iOS SDK is installed in this environment, so the full iOS app could not be compiled here.
- The Apple GameController API names and DualSense mapping were cross-checked against Apple's current documentation, but no physical DualSense/iPhone was available for Bluetooth testing.
- No Xbox was available to confirm the WebSocket handshake, Xbox pairing probe, and live input injection end to end.

The GitHub Actions workflow is intended to perform the missing iOS compile on a GitHub-hosted macOS runner. A successful runner build still needs a real iPhone + Xbox test before this should be called fully working.
