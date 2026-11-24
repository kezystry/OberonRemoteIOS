import Foundation
import Combine
import GameController

/// Reads a single physical controller and publishes an Oberon-compatible snapshot.
/// Game Controller callbacks are explicitly delivered on the main queue; the packet
/// itself is protected because the WebSocket server reads it from its own queue.
final class GamepadManager: ObservableObject {
    @Published private(set) var controllerName = "No controller detected"
    @Published private(set) var profileDescription = "Pair a DualSense or another extended gamepad"
    @Published private(set) var isConnected = false
    @Published private(set) var isDiscovering = false

    private let packetLock = NSLock()
    private var latestPacket = OberonProtocol.emptyPacket()
    private var activeController: GCController?
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.considerConnectedController(controller)
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.detach(controller)
        })
        refresh()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Refreshes the list of controllers already connected to iOS.
    func refresh() {
        let controllers = GCController.controllers().filter { $0.extendedGamepad != nil }
        let preferred = controllers.first(where: { $0.extendedGamepad is GCDualSenseGamepad })
            ?? (GCController.current?.extendedGamepad != nil ? GCController.current : nil)
            ?? controllers.first

        guard let preferred else {
            if let old = activeController {
                old.extendedGamepad?.valueChangedHandler = nil
            }
            activeController = nil
            controllerName = "No controller detected"
            profileDescription = "Pair a DualSense or another extended gamepad"
            isConnected = false
            store(OberonProtocol.emptyPacket())
            return
        }
        attach(preferred)
    }

    private func considerConnectedController(_ controller: GCController) {
        guard controller.extendedGamepad != nil else { return }
        guard let activeController else {
            attach(controller)
            return
        }
        // If iOS reports more than one controller, keep the DualSense as the
        // preferred device instead of switching to a later non-Sony connection.
        let activeIsDualSense = activeController.extendedGamepad is GCDualSenseGamepad
        let newIsDualSense = controller.extendedGamepad is GCDualSenseGamepad
        if !activeIsDualSense && newIsDualSense {
            attach(controller)
        }
    }

    /// Starts Apple's wireless-controller discovery when the user taps Find Controller.
    /// Pairing itself is still completed through iOS Bluetooth Settings when required.
    func discover() {
        refresh()
        guard !isConnected, !isDiscovering else { return }
        isDiscovering = true
        GCController.startWirelessControllerDiscovery { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isDiscovering = false
                self.refresh()
            }
        }
    }

    func stopDiscovery() {
        GCController.stopWirelessControllerDiscovery()
        isDiscovering = false
    }

    /// Safe to call from the WebSocket queue.
    func snapshot() -> [UInt8] {
        packetLock.lock()
        defer { packetLock.unlock() }
        return latestPacket
    }

    private func attach(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        if activeController !== controller {
            activeController?.extendedGamepad?.valueChangedHandler = nil
        }
        activeController = controller
        controller.handlerQueue = .main

        if let home = gamepad.buttonHome {
            // Let this app forward the PS button as Oberon's Xbox/Guide button.
            home.preferredSystemGestureState = .disabled
        }

        if gamepad is GCDualSenseGamepad {
            controllerName = "Sony DualSense"
            profileDescription = "DualSense profile detected · Create and touchpad mapped to View"
        } else if gamepad is GCDualShockGamepad {
            controllerName = "Sony DualShock 4"
            profileDescription = "DualShock profile detected · Share and touchpad mapped to View"
        } else {
            controllerName = controller.vendorName ?? "Bluetooth game controller"
            profileDescription = "Extended gamepad profile detected"
        }
        isConnected = true
        stopDiscovery()

        // GCController.handlerQueue defaults to main; set it explicitly above so the
        // state snapshot can be updated immediately without queuing a Task per event.
        gamepad.valueChangedHandler = { [weak self] _, _ in
            self?.updatePacket()
        }
        updatePacket()
    }

    private func detach(_ controller: GCController) {
        guard activeController === controller else { return }
        controller.extendedGamepad?.valueChangedHandler = nil
        activeController = nil
        controllerName = "No controller detected"
        profileDescription = "Pair a DualSense or another extended gamepad"
        isConnected = false
        store(OberonProtocol.emptyPacket())
        refresh()
    }

    private func updatePacket() {
        guard let gamepad = activeController?.extendedGamepad else {
            store(OberonProtocol.emptyPacket())
            return
        }

        // Apple's DualSense profile maps Cross/Circle/Square/Triangle to A/B/X/Y,
        // Options to buttonMenu, Create to buttonOptions, and PS to buttonHome.
        // The clickable touchpad is an additional View/Back equivalent.
        let dualSense = gamepad as? GCDualSenseGamepad
        let dualShock = gamepad as? GCDualShockGamepad
        let touchpadClick = dualSense?.touchpadButton.isPressed
            ?? dualShock?.touchpadButton.isPressed
            ?? false

        let packet = OberonProtocol.makePacket(
            leftX: gamepad.leftThumbstick.xAxis.value,
            leftY: gamepad.leftThumbstick.yAxis.value,
            rightX: gamepad.rightThumbstick.xAxis.value,
            rightY: gamepad.rightThumbstick.yAxis.value,
            leftTrigger: gamepad.leftTrigger.value,
            rightTrigger: gamepad.rightTrigger.value,
            a: gamepad.buttonA.isPressed,
            b: gamepad.buttonB.isPressed,
            x: gamepad.buttonX.isPressed,
            y: gamepad.buttonY.isPressed,
            view: OberonProtocol.viewButtonPressed(
                createOrSharePressed: gamepad.buttonOptions?.isPressed ?? false,
                touchpadClickPressed: touchpadClick
            ),
            menu: gamepad.buttonMenu.isPressed,
            guide: gamepad.buttonHome?.isPressed ?? false,
            leftShoulder: gamepad.leftShoulder.isPressed,
            rightShoulder: gamepad.rightShoulder.isPressed,
            leftStick: gamepad.leftThumbstickButton?.isPressed ?? false,
            rightStick: gamepad.rightThumbstickButton?.isPressed ?? false,
            dpadUp: gamepad.dpad.up.isPressed,
            dpadDown: gamepad.dpad.down.isPressed,
            dpadLeft: gamepad.dpad.left.isPressed,
            dpadRight: gamepad.dpad.right.isPressed
        )
        store(packet)
    }

    private func store(_ packet: [UInt8]) {
        packetLock.lock()
        latestPacket = packet
        packetLock.unlock()
    }
}
