import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var gamepad: GamepadManager
    @StateObject private var server: OberonServer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let manager = GamepadManager()
        _gamepad = StateObject(wrappedValue: manager)
        _server = StateObject(wrappedValue: OberonServer(packetProvider: { manager.snapshot() }))
    }

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.055, blue: 0.065).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OBERON REMOTE")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(2.4)
                            .foregroundStyle(Color.green)
                        Text("iPhone Input Server")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Connect your controller to this iPhone, then connect your Xbox to the address below.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("SERVER ADDRESS", systemImage: "dot.radiowaves.left.and.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.65))
                            Spacer()
                            Text("PORT 26401")
                                .font(.caption2.monospaced().weight(.bold))
                                .foregroundStyle(Color.green)
                        }
                        Text(server.ipAddress)
                            .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                            .textSelection(.enabled)
                        Text("Enter this IP address in the Oberon app on your Xbox. The port is added automatically.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                        Button {
                            UIPasteboard.general.string = server.ipAddress
                        } label: {
                            Label("Copy IP address", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("CONTROLLER", systemImage: "gamecontroller.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.65))
                        HStack(spacing: 12) {
                            Image(systemName: gamepad.isConnected ? "gamecontroller.fill" : "gamecontroller")
                                .font(.title2)
                                .foregroundStyle(gamepad.isConnected ? Color.green : .white.opacity(0.5))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(gamepad.isConnected ? gamepad.controllerName : "No controller detected")
                                    .font(.headline)
                                Text(gamepad.isConnected ? gamepad.profileDescription : (gamepad.isDiscovering ? "Searching for wireless controllers…" : "Pair in iPhone Settings → Bluetooth"))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            Circle()
                                .fill(gamepad.isConnected ? Color.green : Color.gray)
                                .frame(width: 9, height: 9)
                        }
                        Button { gamepad.discover() } label: {
                            Label(gamepad.isDiscovering ? "Searching…" : (gamepad.isConnected ? "Refresh controller" : "Find controller"), systemImage: "dot.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("CONNECTION", systemImage: "network")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.65))
                            Spacer()
                            Circle().fill(server.isRunning ? Color.green : Color.gray).frame(width: 8, height: 8)
                            Text(server.isRunning ? "ACTIVE" : "STOPPED")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(server.isRunning ? Color.green : .white.opacity(0.55))
                        }
                        Text(server.status)
                            .font(.headline)
                        HStack {
                            metric("Xbox clients", value: "\(server.clientCount)")
                            metric("Input requests", value: "\(server.requestCount)")
                        }
                        Button {
                            if server.isRunning { server.stop() } else { server.start() }
                        } label: {
                            Text(server.isRunning ? "Stop input server" : "Start input server")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 8) {
                        Label("DUALSENSE PAIRING", systemImage: "gamecontroller")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.green)
                        Text("To pair a DualSense, hold the PS button and Create button together until the light bar flashes, then select DualSense in iPhone Settings → Bluetooth. Return here and tap Find controller. The Create button and touchpad click both act as Xbox View; the PS button acts as Xbox Guide.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("IMPORTANT", systemImage: "info.circle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.green)
                        Text("Keep this app open in the foreground while playing. iOS stops this server when the app moves into the background. Keep the Xbox and iPhone on the same local Wi-Fi network. The server has no password: only run it on a trusted home network.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.horizontal, 4)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = server.isRunning; gamepad.refresh(); server.refreshAddress() }
        .onChange(of: server.isRunning) { isRunning in
            // Keep the display awake only while the input server is actually active.
            UIApplication.shared.isIdleTimerDisabled = isRunning
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                UIApplication.shared.isIdleTimerDisabled = server.isRunning
                gamepad.refresh()
                server.refreshAddress()
            } else if phase == .background {
                UIApplication.shared.isIdleTimerDisabled = false
                gamepad.stopDiscovery()
                server.stop()
            }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title3.weight(.bold).monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.black)
            .background(Color.green.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 11))
    }
}
