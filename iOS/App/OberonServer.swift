import Foundation
import Combine
import Network
import Darwin

final class OberonServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Server stopped"
    @Published private(set) var clientCount = 0
    @Published private(set) var requestCount: UInt64 = 0
    @Published private(set) var ipAddress = LocalAddress.wifiIPv4() ?? "No Wi-Fi IPv4"

    private let port = NWEndpoint.Port(rawValue: 26401)!
    private let machineName = "Oberon iPhone"
    private let queue = DispatchQueue(label: "oberon.ios.websocket.server")
    private let packetProvider: () -> [UInt8]
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: NWConnection] = [:]
    // These values are mutated only on `queue`. UI publication is throttled so a
    // high-rate controller poll loop can't flood the main queue with counter updates.
    private var processedRequestCount: UInt64 = 0
    private var lastRequestCountPublish = DispatchTime.now().uptimeNanoseconds

    init(packetProvider: @escaping () -> [UInt8]) {
        self.packetProvider = packetProvider
    }

    func refreshAddress() {
        ipAddress = LocalAddress.wifiIPv4() ?? "No Wi-Fi IPv4"
    }

    func start() {
        guard listener == nil else { return }
        guard let address = LocalAddress.wifiIPv4() else {
            ipAddress = "No Wi-Fi IPv4"
            status = "Connect this iPhone to the same Wi-Fi network as the Xbox"
            return
        }
        ipAddress = address
        do {
            let websocket = NWProtocolWebSocket.Options()
            websocket.autoReplyPing = true
            websocket.setClientRequestHandler(queue) { _, _ in
                NWProtocolWebSocket.Response(status: .accept, subprotocol: nil, additionalHeaders: nil)
            }
            let parameters = NWParameters.tcp
            parameters.defaultProtocolStack.applicationProtocols.insert(websocket, at: 0)

            let newListener = try NWListener(using: parameters, on: port)
            newListener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.refreshAddress()
                        self?.isRunning = true
                        self?.status = "Waiting for Xbox connection"
                    case .waiting(let error):
                        self?.isRunning = false
                        self?.status = "Waiting for network: \(error.localizedDescription)"
                    case .failed(let error):
                        self?.isRunning = false
                        self?.status = "Server error: \(error.localizedDescription)"
                        self?.listener?.cancel()
                        self?.listener = nil
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            newListener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener = newListener
            newListener.start(queue: queue)
            DispatchQueue.main.async { self.status = "Starting server…" }
        } catch {
            status = "Could not start: \(error.localizedDescription)"
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        queue.async {
            self.clients.values.forEach { $0.cancel() }
            self.clients.removeAll()
            let finalRequestCount = self.processedRequestCount
            DispatchQueue.main.async {
                self.isRunning = false
                self.clientCount = 0
                self.requestCount = finalRequestCount
                self.status = "Server stopped"
            }
        }
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        clients[id] = connection
        let connectedCount = clients.count
        DispatchQueue.main.async {
            self.clientCount = connectedCount
            self.status = "Xbox connected"
        }
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.sendBinary(Data(OberonProtocol.handshake(machineName: self.machineName)), on: connection)
                self.receive(on: connection)
            case .failed, .cancelled:
                self.clients.removeValue(forKey: id)
                let remaining = self.clients.count
                DispatchQueue.main.async {
                    self.clientCount = remaining
                    if remaining == 0 && self.isRunning {
                        self.status = "Waiting for Xbox connection"
                    }
                }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] content, _, _, error in
            guard let self, let connection else { return }
            if let content, !content.isEmpty {
                // Oberon's only application request frame begins with 0xFA.
                // Checking the magic byte avoids relying on WebSocket metadata APIs
                // for receive-side frame classification.
                if OberonProtocol.isInputRequest(content) {
                    // The Xbox sends 0xFA followed by 16 rumble bytes. iOS controllers
                    // are treated as input-only here; vibration feedback is not forwarded.
                    let snapshot = self.packetProvider()
                    // Oberon expects exactly four 25-byte controller slots. Never send
                    // a malformed packet if a future input provider changes unexpectedly.
                    let packet = snapshot.count == OberonProtocol.packetSize
                        ? Data(snapshot)
                        : Data(OberonProtocol.emptyPacket())
                    self.sendBinary(packet, on: connection)
                    self.processedRequestCount &+= 1
                    let now = DispatchTime.now().uptimeNanoseconds
                    if now - self.lastRequestCountPublish >= 250_000_000 {
                        self.lastRequestCountPublish = now
                        let displayedCount = self.processedRequestCount
                        DispatchQueue.main.async { self.requestCount = displayedCount }
                    }
                }
            }
            if error != nil {
                connection.cancel()
                return
            }
            guard connection.state == .ready else { return }
            self.receive(on: connection)
        }
    }

    private func sendBinary(_ data: Data, on connection: NWConnection) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "oberon-binary", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true,
                        completion: .contentProcessed { _ in })
    }
}

enum LocalAddress {
    /// iPhone Wi-Fi is normally en0. Prefer it, but retain a fallback for devices
    /// whose active Wi-Fi/Ethernet interface is exposed under another en* name.
    static func wifiIPv4() -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var fallback: String?
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor {
            let interface = item.pointee
            if let address = interface.ifa_addr,
               address.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name.hasPrefix("en") {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(address, socklen_t(address.pointee.sa_len),
                                             &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                    if result == 0 {
                        let ip = String(cString: host)
                        // Do not advertise an unusable address when Wi-Fi has no
                        // DHCP lease (for example, a self-assigned 169.254/16 IP).
                        guard ip != "0.0.0.0", !ip.hasPrefix("127."),
                              !ip.hasPrefix("169.254.") else {
                            cursor = interface.ifa_next
                            continue
                        }
                        if name == "en0" { return ip }
                        if fallback == nil { fallback = ip }
                    }
                }
            }
            cursor = interface.ifa_next
        }
        return fallback
    }
}
