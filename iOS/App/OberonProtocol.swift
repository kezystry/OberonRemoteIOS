import Foundation

/// Oberon Remote Input's controller packet: four 25-byte slots (100 bytes total).
enum OberonProtocol {
    static let packetSize = 100

    /// Original Oberon pairing probe expects a binary message beginning with 0x0A,
    /// followed by the UTF-8 remote name (the leading byte is also a newline in its
    /// pairing-result string parsing).
    static func handshake(machineName: String) -> [UInt8] {
        [0x0A] + Array(machineName.utf8)
    }

    /// Xbox-side SocketClient sends a binary request whose first byte is 0xFA.
    static func isInputRequest(_ frame: Data) -> Bool {
        frame.first == 0xFA
    }

    static func emptyPacket() -> [UInt8] {
        // Slot 0 is populated when a controller is connected.
        return [UInt8](repeating: 0, count: packetSize)
    }

    /// DualSense Create and touchpad-click are both mapped to Xbox View/Back.
    static func viewButtonPressed(createOrSharePressed: Bool, touchpadClickPressed: Bool) -> Bool {
        createOrSharePressed || touchpadClickPressed
    }

    static func makePacket(
        leftX: Float, leftY: Float,
        rightX: Float, rightY: Float,
        leftTrigger: Float, rightTrigger: Float,
        a: Bool, b: Bool, x: Bool, y: Bool,
        view: Bool, menu: Bool, guide: Bool,
        leftShoulder: Bool, rightShoulder: Bool,
        leftStick: Bool, rightStick: Bool,
        dpadUp: Bool, dpadDown: Bool, dpadLeft: Bool, dpadRight: Bool
    ) -> [UInt8] {
        var packet = emptyPacket()
        let base = 0
        packet[base] = 0xFF

        func axis(_ value: Float, invert: Bool = false) -> Int16 {
            let adjusted = invert ? -value : value
            let clamped = max(-1.0, min(1.0, adjusted))
            return Int16((clamped * 32767.0).rounded())
        }

        func trigger(_ value: Float) -> Int16 {
            let clamped = max(0.0, min(1.0, value))
            return Int16((clamped * 32767.0).rounded())
        }

        func writeInt16(_ value: Int16, at offset: Int) {
            let raw = UInt16(bitPattern: value)
            packet[base + offset] = UInt8(raw & 0x00FF)
            packet[base + offset + 1] = UInt8((raw >> 8) & 0x00FF)
        }

        writeInt16(axis(leftX), at: 1)
        // Apple's GameController stick Y is positive upwards. Oberon expects SDL's
        // convention (negative upwards), because the Xbox app inverts Y on receipt.
        writeInt16(axis(leftY, invert: true), at: 3)
        writeInt16(axis(rightX), at: 5)
        writeInt16(axis(rightY, invert: true), at: 7)
        writeInt16(trigger(leftTrigger), at: 9)
        writeInt16(trigger(rightTrigger), at: 11)

        func setBit(_ byte: Int, _ bit: Int, _ pressed: Bool) {
            if pressed { packet[base + byte] |= UInt8(1 << bit) }
        }

        // Byte 13: face buttons, shoulders, menu and view.
        setBit(13, 7, a)
        setBit(13, 6, b)
        setBit(13, 5, x)
        setBit(13, 4, y)
        setBit(13, 3, leftShoulder)
        setBit(13, 2, rightShoulder)
        setBit(13, 1, menu)
        setBit(13, 0, view)

        // Byte 14: stick clicks, D-pad and Xbox/guide button.
        setBit(14, 6, leftStick)
        setBit(14, 5, rightStick)
        setBit(14, 4, dpadUp)
        setBit(14, 3, dpadDown)
        setBit(14, 2, dpadLeft)
        setBit(14, 1, dpadRight)
        setBit(14, 0, guide)
        return packet
    }
}
