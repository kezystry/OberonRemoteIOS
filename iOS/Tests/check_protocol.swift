import Foundation

@inline(__always) func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let handshake = OberonProtocol.handshake(machineName: "Oberon iPhone")
expect(handshake.first == 0x0A, "pairing handshake begins with Oberon's 0x0A marker")
expect(String(decoding: handshake.dropFirst(), as: UTF8.self) == "Oberon iPhone", "pairing handshake contains the UTF-8 remote name")
let xboxRequest = Data([0xFA] + [UInt8](repeating: 0, count: 16))
expect(xboxRequest.count == 17, "Xbox request fixture is 17 bytes")
expect(OberonProtocol.isInputRequest(xboxRequest), "Xbox's 17-byte input request is recognized")
expect(!OberonProtocol.isInputRequest(Data()), "empty WebSocket payload is ignored")
expect(!OberonProtocol.isInputRequest(Data([0x0A, 0x01])), "handshake marker is not mistaken for an input request")
expect(!OberonProtocol.isInputRequest(Data([0xFF] + [UInt8](repeating: 0, count: 99))), "controller reply is not mistaken for an Xbox request")

expect(!OberonProtocol.viewButtonPressed(createOrSharePressed: false, touchpadClickPressed: false), "View remains released when Create and touchpad are released")
expect(OberonProtocol.viewButtonPressed(createOrSharePressed: true, touchpadClickPressed: false), "DualSense Create maps to View")
expect(OberonProtocol.viewButtonPressed(createOrSharePressed: false, touchpadClickPressed: true), "DualSense touchpad click maps to View")
expect(OberonProtocol.viewButtonPressed(createOrSharePressed: true, touchpadClickPressed: true), "Create and touchpad can be pressed together without losing View")

let neutral = OberonProtocol.emptyPacket()
expect(neutral.count == 100, "neutral frame is exactly 100 bytes")
expect(neutral.allSatisfy { $0 == 0 }, "neutral frame has no active controller slots")

let frame = OberonProtocol.makePacket(
    leftX: 1, leftY: 1, rightX: -1, rightY: -1,
    leftTrigger: 1, rightTrigger: 0.5,
    a: true, b: true, x: true, y: true,
    view: true, menu: true, guide: true,
    leftShoulder: true, rightShoulder: true,
    leftStick: true, rightStick: true,
    dpadUp: true, dpadDown: true, dpadLeft: true, dpadRight: true
)
expect(frame.count == 100, "active frame is exactly 100 bytes")
expect(frame[0] == 0xFF, "slot 1 is marked active")
expect(frame[1] == 0xFF && frame[2] == 0x7F, "left stick X is little-endian +32767")
expect(frame[3] == 0x01 && frame[4] == 0x80, "left stick Y is inverted for Oberon/Xbox receiver")
expect(frame[5] == 0x01 && frame[6] == 0x80, "right stick X is little-endian -32767")
expect(frame[7] == 0xFF && frame[8] == 0x7F, "right stick Y is inverted for Oberon/Xbox receiver")
expect(frame[9] == 0xFF && frame[10] == 0x7F, "left trigger reaches full range")
expect(frame[11] == 0x00 && frame[12] == 0x40, "right trigger reaches half range")
expect(frame[13] == 0xFF, "byte 13 face, shoulder, menu and view bits match Oberon")
expect(frame[14] == 0x7F, "byte 14 stick, d-pad and guide bits match Oberon")
expect(frame[15...24].allSatisfy { $0 == 0 }, "unused bytes in slot 1 are zero")
expect(frame[25...99].allSatisfy { $0 == 0 }, "slots 2-4 remain inactive")

print("PASS: Oberon protocol checks (handshake, request detection, DualSense View mapping, 100-byte packets, axes, triggers, button bits, slot layout)")
