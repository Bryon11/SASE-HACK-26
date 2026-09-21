import Foundation
import CoreBluetooth
import Observation

/// Single entry point for the cap. In `.live` mode it talks CoreBluetooth; in
/// `.simulator` mode it builds real JSON messages in the firmware's format and
/// feeds them through the SAME parser, so the demo exercises the production path.
@MainActor
@Observable
final class SmartCapManager: NSObject {

    enum Mode: String, CaseIterable, Identifiable {
        case live, simulator
        var id: String { rawValue }
        var label: String { self == .live ? "Real cap" : "Simulator" }
    }

    enum ConnectionState: Equatable {
        case bluetoothOff, unauthorized, unsupported
        case idle, scanning, connecting
        case connected(name: String)
        case simulated

        var label: String {
            switch self {
            case .bluetoothOff: "Bluetooth is off"
            case .unauthorized: "Bluetooth not allowed"
            case .unsupported: "Bluetooth unavailable"
            case .idle: "Tap to connect"
            case .scanning: "Looking for cap…"
            case .connecting: "Connecting…"
            case .connected(let name): name
            case .simulated: "Simulated cap"
            }
        }

        var isReady: Bool {
            switch self {
            case .connected, .simulated: true
            default: false
            }
        }
    }

    // MARK: Observable state

    private(set) var mode: Mode
    private(set) var connectionState: ConnectionState = .idle
    private(set) var batteryPercent: Int?
    private(set) var isCapOpen = false
    /// The IMU says the bottle is tipped, so readings are being ignored.
    private(set) var isTilted = false
    /// What the float sensor says is in the bottle right now.
    private(set) var bottleVolumeOz: Double?
    private(set) var lastVolumeDate: Date?
    /// What the device itself has counted today — a cross-check on our own total.
    private(set) var deviceDailyIntakeOz: Double?
    private(set) var isAutoDemoRunning = false
    private(set) var lastEventDate: Date?
    /// Newest first; shown in the simulator console.
    private(set) var eventLog: [String] = []
    /// Re-stamped every minute so "we haven't heard from the cap" updates on its own.
    private(set) var healthCheckedAt = Date.now

    /// Fired for every drink the cap reports (ounces).
    @ObservationIgnored var onSip: ((Double, LogSource) -> Void)?
    /// Fired whenever the cap reports how full the bottle is (ounces).
    @ObservationIgnored var onBottleLevel: ((Double) -> Void)?

    // MARK: Private

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var buffer = JSONLineBuffer()
    @ObservationIgnored private var lastPayloadIdentity: String?
    @ObservationIgnored private var autoDemoTask: Task<Void, Never>?
    @ObservationIgnored private var capAnimationTask: Task<Void, Never>?
    @ObservationIgnored private var healthTask: Task<Void, Never>?
    @ObservationIgnored private var silentAlertSent = false

    /// Bottle size and level used when the simulator makes up readings.
    @ObservationIgnored private var simulatedCapacityOz: Double = 24
    @ObservationIgnored private var simulatedVolumeOz: Double = 24

    private let modeKey = "smartsip.capMode"
    private let savedPeripheralKey = "smartsip.lastPeripheralID"

    /// Connected but no messages for this long = something is wrong with the cap.
    static let silenceThreshold: TimeInterval = 3 * 3600

    override init() {
        #if targetEnvironment(simulator)
        mode = .simulator // the iOS Simulator has no Bluetooth radio
        #else
        mode = UserDefaults.standard.string(forKey: "smartsip.capMode").flatMap(Mode.init) ?? .live
        #endif
        super.init()
        if mode == .simulator {
            connectionState = .simulated
            batteryPercent = 87
        }
        startHealthMonitor()
    }

    // MARK: Cap health

    var health: CapHealth {
        if let battery = batteryPercent {
            if battery <= 0 { return .batteryDead }
            if battery <= 10 { return .criticalBattery(battery) }
            if battery <= 20 { return .lowBattery(battery) }
        }
        if connectionState.isReady, let last = lastEventDate,
           healthCheckedAt.timeIntervalSince(last) > Self.silenceThreshold {
            return .silent(since: last)
        }
        if lastEventDate == nil && batteryPercent == nil { return .unknown }
        return .ok
    }

    private func startHealthMonitor() {
        healthTask?.cancel()
        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, let self else { return }
                self.healthCheckedAt = .now
                self.checkForSilence()
            }
        }
    }

    private func checkForSilence() {
        guard case .silent(let since) = health else {
            silentAlertSent = false
            return
        }
        guard !silentAlertSent else { return }
        silentAlertSent = true
        CapAlerts.capWentQuiet(lastSeen: since)
    }

    // MARK: Mode switching

    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: modeKey)
        buffer.reset()
        lastPayloadIdentity = nil
        isCapOpen = false
        isTilted = false

        switch newMode {
        case .simulator:
            disconnectLive()
            connectionState = .simulated
            batteryPercent = 87
            appendLog("Switched to simulator")
        case .live:
            stopAutoDemo()
            connectionState = .idle
            batteryPercent = nil
            bottleVolumeOz = nil
            appendLog("Switched to real cap")
            startLive()
        }
    }

    // MARK: Live (CoreBluetooth)

    /// Lazily creates the central so simulator users never see a Bluetooth prompt.
    func startLive() {
        guard mode == .live else { return }
        if let central {
            handleStateUpdate(central)
        } else {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    func scan() {
        guard mode == .live, let central, central.state == .poweredOn else { return }
        connectionState = .scanning
        central.scanForPeripherals(withServices: [SmartCapUUIDs.service], options: nil)
    }

    func forgetDevice() {
        UserDefaults.standard.removeObject(forKey: savedPeripheralKey)
        disconnectLive()
        connectionState = .idle
        scan()
    }

    private func disconnectLive() {
        guard let central else { return }
        if central.state == .poweredOn { central.stopScan() }
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil
    }

    private func handleStateUpdate(_ central: CBCentralManager) {
        guard mode == .live else { return }
        switch central.state {
        case .poweredOn: reconnectOrScan()
        case .poweredOff: connectionState = .bluetoothOff
        case .unauthorized: connectionState = .unauthorized
        case .unsupported: connectionState = .unsupported
        default: connectionState = .idle
        }
    }

    private func reconnectOrScan() {
        guard let central else { return }
        if let idString = UserDefaults.standard.string(forKey: savedPeripheralKey),
           let uuid = UUID(uuidString: idString),
           let known = central.retrievePeripherals(withIdentifiers: [uuid]).first {
            connect(known) // pending connects never time out → acts as auto-reconnect
        } else {
            scan()
        }
    }

    private func connect(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        connectionState = .connecting
        central?.connect(p, options: nil)
    }

    // MARK: Simulator

    /// The simulator needs to know how big the bottle is to fake volumes.
    func setSimulatedCapacity(_ ounces: Double) {
        guard ounces > 0, ounces != simulatedCapacityOz else { return }
        simulatedCapacityOz = ounces
        simulatedVolumeOz = min(simulatedVolumeOz, ounces)
    }

    /// Plays a drink: the cap lifts, then the firmware's "drink" message arrives.
    func simulateTwist(ounces: Double, openDuration: TimeInterval = 1.2) async {
        guard mode == .simulator else { return }
        showCapOpen(for: openDuration + 0.2)
        try? await Task.sleep(for: .seconds(openDuration))
        guard mode == .simulator else { return }
        simulatedVolumeOz = max(simulatedVolumeOz - ounces, 0)
        emit(event: "drink", amountOunces: ounces)
    }

    func simulateRefill(toOunces ounces: Double? = nil) {
        guard mode == .simulator else { return }
        let filled = ounces ?? simulatedCapacityOz
        let added = max(filled - simulatedVolumeOz, 0)
        simulatedVolumeOz = filled
        emit(event: "refill", amountOunces: added)
    }

    func simulateTilt(_ tilted: Bool) {
        guard mode == .simulator else { return }
        emit(event: "idle", amountOunces: nil, tilted: tilted)
    }

    func simulateBattery(_ percent: Int) {
        guard mode == .simulator else { return }
        emit(event: "idle", amountOunces: nil, battery: max(0, min(percent, 100)))
    }

    /// Proves garbage over the air can't crash the app.
    func simulateMalformedPacket() {
        guard mode == .simulator else { return }
        handleIncoming(Data("{\"volume\": oops\n".utf8), source: .simulator)
    }

    /// Demo: pretend the cap stopped reporting hours ago.
    func simulateSilentCap(hoursAgo: Double = 5) {
        stopAutoDemo()
        lastEventDate = Date.now.addingTimeInterval(-hoursAgo * 3600)
        healthCheckedAt = .now
        silentAlertSent = false
        appendLog("Simulated cap going quiet")
        checkForSilence()
    }

    func toggleAutoDemo() {
        isAutoDemoRunning ? stopAutoDemo() : startAutoDemo()
    }

    func stopAutoDemo() {
        autoDemoTask?.cancel()
        autoDemoTask = nil
        isAutoDemoRunning = false
    }

    private func startAutoDemo() {
        guard mode == .simulator else { return }
        isAutoDemoRunning = true
        autoDemoTask = Task { [weak self] in
            let sipSizes: [Double] = [2, 3, 4, 6]
            while !Task.isCancelled {
                let delay: Double = Double.random(in: 5.0...9.0)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                if self.simulatedVolumeOz < 2 { self.simulateRefill() }
                let ounces: Double = sipSizes.randomElement() ?? 4.0
                await self.simulateTwist(ounces: ounces, openDuration: 1.0)
            }
        }
    }

    /// Builds a message in exactly the firmware's format and runs it through the parser.
    private func emit(event: String, amountOunces: Double?, tilted: Bool = false, battery: Int? = nil) {
        let drinkOunces = event == "drink" ? (amountOunces ?? 0) : 0
        let dailySoFar = deviceDailyIntakeOz ?? 0
        let payload = CapPayload(
            volume: VolumeUnits.milliliters(fromOunces: simulatedVolumeOz),
            event: event,
            amount: amountOunces.map { VolumeUnits.milliliters(fromOunces: $0) },
            dailyIntake: VolumeUnits.milliliters(fromOunces: dailySoFar + drinkOunces),
            status: tilted ? "tilted" : "upright",
            timestamp: Date.now.timeIntervalSince1970,
            battery: battery
        )
        handleIncoming(payload.encoded, source: .simulator)
    }

    private func showCapOpen(for duration: TimeInterval) {
        capAnimationTask?.cancel()
        isCapOpen = true
        capAnimationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.isCapOpen = false
        }
    }

    // MARK: Shared message pipeline

    private func handleIncoming(_ data: Data, source: LogSource) {
        let payloads = buffer.append(data)
        guard !payloads.isEmpty else {
            appendLog("Incomplete or unreadable message ignored")
            return
        }
        for payload in payloads { handle(payload, source: source) }
    }

    private func handle(_ payload: CapPayload, source: LogSource) {
        // The firmware may resend the same reading; only act on new ones.
        guard payload.identity != lastPayloadIdentity else { return }
        lastPayloadIdentity = payload.identity

        lastEventDate = .now
        healthCheckedAt = .now
        silentAlertSent = false
        isTilted = payload.isTilted

        if let volume = payload.volume {
            let ounces = VolumeUnits.ounces(fromMilliliters: volume)
            bottleVolumeOz = ounces
            lastVolumeDate = .now
            simulatedVolumeOz = ounces
            onBottleLevel?(ounces)
        }
        if let daily = payload.dailyIntake {
            deviceDailyIntakeOz = VolumeUnits.ounces(fromMilliliters: daily)
        }
        if let battery = payload.battery {
            batteryPercent = battery
            CapAlerts.batteryChanged(to: battery)
        }

        switch payload.kind {
        case .drink:
            let ounces = VolumeUnits.ounces(fromMilliliters: payload.amount ?? 0)
            if ounces > 0 {
                if source == .smartCap { showCapOpen(for: 1.0) }
                onSip?(ounces, source)
                appendLog("Drink \(ounces.ozText) · bottle \(bottleVolumeOz?.ozText ?? "?")")
            }
        case .refill:
            let ounces = VolumeUnits.ounces(fromMilliliters: payload.amount ?? 0)
            appendLog("Refill +\(ounces.ozText) · bottle \(bottleVolumeOz?.ozText ?? "?")")
        case .idle:
            appendLog("Reading \(bottleVolumeOz?.ozText ?? "?")\(payload.isTilted ? " · tilted" : "")")
        case .unknown:
            appendLog("Unknown event \"\(payload.event ?? "")\"")
        }
    }

    private func appendLog(_ line: String) {
        let time = Date.now.formatted(date: .omitted, time: .standard)
        eventLog.insert("\(time)  \(line)", at: 0)
        if eventLog.count > 8 { eventLog.removeLast() }
    }
}

// MARK: - CBCentralManagerDelegate
// Delegates are delivered on the main queue (see init), so assumeIsolated is safe.

extension SmartCapManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated { self.handleStateUpdate(central) }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        MainActor.assumeIsolated {
            guard self.mode == .live else { return }
            central.stopScan()
            self.appendLog("Found \(peripheral.name ?? "cap") (RSSI \(RSSI))")
            self.connect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: self.savedPeripheralKey)
            self.connectionState = .connected(name: peripheral.name ?? "Hydrometer Cap")
            self.buffer.reset()
            self.lastPayloadIdentity = nil
            self.appendLog("Connected")
            peripheral.discoverServices([SmartCapUUIDs.service, SmartCapUUIDs.batteryService])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            self.appendLog("Connect failed: \(error?.localizedDescription ?? "unknown")")
            self.peripheral = nil
            self.scan()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            guard self.mode == .live, self.peripheral?.identifier == peripheral.identifier else { return }
            self.isCapOpen = false
            self.buffer.reset()
            self.appendLog("Disconnected — will reconnect when in range")
            self.connect(peripheral)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension SmartCapManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            for service in peripheral.services ?? [] {
                if service.uuid == SmartCapUUIDs.service {
                    peripheral.discoverCharacteristics([SmartCapUUIDs.events], for: service)
                } else if service.uuid == SmartCapUUIDs.batteryService {
                    peripheral.discoverCharacteristics([SmartCapUUIDs.batteryLevel], for: service)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == SmartCapUUIDs.events {
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if characteristic.uuid == SmartCapUUIDs.batteryLevel {
                    peripheral.readValue(for: characteristic)
                    if characteristic.properties.contains(.notify) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            guard error == nil, let data = characteristic.value else { return }
            if characteristic.uuid == SmartCapUUIDs.batteryLevel, let level = data.first {
                self.batteryPercent = Int(level)
                CapAlerts.batteryChanged(to: Int(level))
            } else if characteristic.uuid == SmartCapUUIDs.events {
                self.handleIncoming(data, source: .smartCap)
            }
        }
    }
}
