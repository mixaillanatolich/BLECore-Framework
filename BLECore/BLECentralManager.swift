//
//  BLECentralManager.swift
//  BLECore
//
//  Created by Mixaill on 12.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation
import CoreBluetooth

public enum BLEDeviceConnectStatus: Int {
    case unknown
    case connecting
    case connected
    case ready
    case disconected
    case timeoutError
    case error
}

public enum BLEDeviceType: Int {
    case unknown
    case expectedDevice
}

public let BLEManager = BLECentralManager.sharedInstance

public class BLECentralManager: NSObject {
    
    fileprivate var centralManager:CBCentralManager!
    fileprivate var bleThread = DispatchQueue(label: "com.m-technologies.bluetooth", attributes: DispatchQueue.Attributes.concurrent)
    fileprivate var peripheral: CBPeripheral?
    
    fileprivate var deviceType = BLEDeviceType.unknown
    
    fileprivate var isScanning: Bool = false
    fileprivate var isPowerOn: Bool = false
    
    fileprivate var serviceUUIDs: [CBUUID]? = [CBUUID.init(string: "0000")]
    
    fileprivate var discoveredDevices = NSMutableSet()
    
    public typealias DiscoveryDeviceCallbackClosure = (_ isNewDevice: Bool, _ device: BLEPeripheral) -> Void
    fileprivate var discoveryDeviceCallback: DiscoveryDeviceCallbackClosure?
    
    public typealias DeviceConnectStatusCallbackClosure = (_ status: BLEDeviceConnectStatus, _ device: CBPeripheral?, _ deviceType: BLEDeviceType, _ error: NSError?) -> Void
    fileprivate var deviceConnectStatusCallback: DeviceConnectStatusCallbackClosure?
    
    fileprivate var timeoutWorkItem: DispatchWorkItem?
    
    var currentDevice: BLEDevicePeripheral? {
        didSet {
            if let device = self.currentDevice {
                device.startDiscoveringServices()
            }
        }
    }
    
    
    public static let sharedInstance: BLECentralManager = {
        let instance = BLECentralManager()
        return instance
    }()
    
    override init() {
        super.init()
        var options = [String : Any]()
        options[CBCentralManagerOptionRestoreIdentifierKey] = "RestoreIdentifierKey"
        options[CBCentralManagerOptionShowPowerAlertKey] = true
        centralManager = CBCentralManager.init(delegate: self, queue: self.bleThread, options: options)
    }
    
    deinit {
        
    }
    
    //MARK: - public
    public func currentBTState() -> CBManagerState {
        dLog("centralManagerDidUpdateState \(centralManager.state.rawValue)")
        return centralManager.state
        /*
         case unknown:      0   (for first request, msg generate by system)
         case resetting:    1               @"The connection with the system service was momentarily lost, update imminent."
         case unsupported:  2               @"The platform doesn't support Bluetooth Low Energy."
         case unauthorized: 3   (bt disabled for app)      @"The app is not authorized to use Bluetooth Low Energy."
         case poweredOff:   4   (bt turned off. generated auto msg)    @"Bluetooth is currently powered off."
         case poweredOn:    5               @"Bluetooth is currently powered on and available to use."
         default:                           @"State unknown, update imminent."
         */
    }
    
    public func alertMsgForCurrentBTState() -> String? {
        dLog("centralManagerDidUpdateState \(centralManager.state.rawValue)")
        switch centralManager.state {
        case .resetting:            return "The connection with the system service was momentarily lost, update imminent."
        case .unsupported:          return "The platform doesn't support Bluetooth Low Energy."
        case .unauthorized:
            switch centralManager.authorization {
                case .allowedAlways:return nil
                case .denied:       return "The app is not authorized to use Bluetooth Low Energy. Access Denied."
                case .restricted:   return "The app is not authorized to use Bluetooth Low Energy. Access Restricted."
                case .notDetermined: return "The app is not authorized to use Bluetooth Low Energy. Access Not Determined"
                default:            return nil
            }
        case .poweredOff:           return "Bluetooth is currently powered off."
        case .poweredOn:            return nil
        default:                    return nil
        }
    }
    
    public func setupDiscoveryDeviceCallback(_ callback: DiscoveryDeviceCallbackClosure?) {
        self.discoveryDeviceCallback = callback
    }
    
    public func setupConnectStatusCallback(_ callback: DeviceConnectStatusCallbackClosure?) {
        self.deviceConnectStatusCallback = callback
    }

    public func startDiscovery(serviceUUIDs: [CBUUID]?) {
        
        if isScanning {
            return
        }
        
        self.serviceUUIDs = serviceUUIDs
        
        discoveredDevices.removeAllObjects()
        isScanning = true
        startScanDevices()
    }
    
    public func stopDiscovery() {
        stopScanDevices()
        isScanning = false
        discoveredDevices.removeAllObjects()
    }
    
    @discardableResult public func bluetoothEnabled() -> Bool {
        return isPowerOn
    }
    
    public func canConnectToPeripheral(with uuid: String) -> CBPeripheral? {
        let devUuid = UUID(uuidString: uuid)!
        let devices = centralManager!.retrievePeripherals(withIdentifiers: [devUuid])
        if !devices.isEmpty {
            return devices[0]
        }
        return nil
    }
    
    private func connectToDevice(_ peripheral: CBPeripheral!, deviceType: BLEDeviceType, timeout: TimeInterval? = nil) {
        // If not already connected to a peripheral, then connect to this one
        if ((self.peripheral == nil) || (self.peripheral?.state == CBPeripheralState.disconnected)) {
            
            // Retain the peripheral before trying to connect
            self.peripheral = peripheral
            
            // Reset service
            self.currentDevice?.reset()
            self.currentDevice = nil
            
            self.deviceType = deviceType
            
            // Connect to peripheral
            centralManager!.connect(peripheral, options:nil)
            
            timeoutWorkItem?.cancel()
            timeoutWorkItem = DispatchWorkItem {
                guard let item = self.timeoutWorkItem, !item.isCancelled else {
                    return
                }
                self.connectionTimeout()
            }
            bleThread.asyncAfter(deadline: .now() + (timeout ?? 30.0), execute: timeoutWorkItem!)
        }
    }
    
    public func disconectFromDevice() {
        // If not already connected to a peripheral, then connect to this one
        if ((self.peripheral != nil) && (self.peripheral?.state != CBPeripheralState.disconnected)) {
            
            // disconect to peripheral
            centralManager!.cancelPeripheralConnection(self.peripheral!)
            
            timeoutWorkItem?.cancel()
        }
    }
    
    public func deviceConnected() -> Bool {
        return currentDevice != nil
    }
    
    public func deviceDisconnected() -> Bool {
        return (self.peripheral == nil) || (self.peripheral?.state == CBPeripheralState.disconnected)
    }
}

extension BLECentralManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        dLog("\(centralManager.state)")
        
        
        switch (central.state) {
        case .poweredOff:
            isPowerOn = false
            self.resetCurrentDevice()
            break
        case .poweredOn:
            isPowerOn = true
            startScanDevices()
        case .resetting:
            self.resetCurrentDevice()
        default:
            break
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        //  dLog("Discovered \(peripheral.identifier) at \(RSSI)")
        
        var newDevice = false
        
        if !discoveredDevices.contains(peripheral) {
            discoveredDevices.add(peripheral)
            newDevice = true
        }
        
        discoveryDeviceCallback?(newDevice, BLEPeripheral(with: peripheral, advertisementData: advertisementData, rssi: RSSI))
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        if (peripheral == self.peripheral) {
            timeoutWorkItem?.cancel()
            
            self.currentDevice = BLEDevicePeripheral(initWith: peripheral)
            deviceConnectStatusCallback?(.connected, peripheral, deviceType, nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        dLog("\(error.orNil)")
        // See if it was our peripheral that disconnected
        
        if (peripheral == self.peripheral) {
            timeoutWorkItem?.cancel()
            
            self.currentDevice?.reset()
            self.currentDevice = nil;
            self.peripheral?.delegate = nil
            self.peripheral = nil;
            
            deviceConnectStatusCallback?(.disconected, peripheral, deviceType, nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        dLog("")
        
        if (peripheral == self.peripheral) {
            timeoutWorkItem?.cancel()
            
            self.currentDevice?.reset()
            self.currentDevice = nil;
            self.peripheral?.delegate = nil
            self.peripheral = nil;
            
            deviceConnectStatusCallback?(.error, peripheral, deviceType, NSError.init(domain: "CommunicationError", code: 38, userInfo: [NSLocalizedDescriptionKey:"Connection to node failed"]) )
        }
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        dLog("\(dict)")
    }
}

extension BLECentralManager {
    
    @objc func connectionTimeout() {
        
        guard let peripheral = self.peripheral else {
            return
        }
        
        guard peripheral.state == .connecting else {
            return
        }
            
        centralManager?.cancelPeripheralConnection(peripheral)
        
        self.currentDevice = nil;
        self.peripheral?.delegate = nil
        self.peripheral = nil;
        
        deviceConnectStatusCallback?(.timeoutError, peripheral, deviceType,  NSError.init(domain: "CommunicationError", code: 37, userInfo: [NSLocalizedDescriptionKey:NSLocalizedString("Connect to device timed out", comment: "") ]) )
        
    }
    
    fileprivate func resetCurrentDevice() {
        self.currentDevice?.reset()
        self.currentDevice = nil
        self.peripheral?.delegate = nil
        self.peripheral = nil
    }
    
    fileprivate func startScanDevices() {
        if isScanning && isPowerOn {
            dLog("Start ble scan")
            centralManager?.scanForPeripherals(withServices: serviceUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    fileprivate func stopScanDevices() {
        if isScanning && isPowerOn {
            dLog("Stop ble scan")
            centralManager?.stopScan()
        }
    }
    
}






private let restoreIdKey = "MyBluetoothManager"
private let peripheralIdDefaultsKey = "MyBluetoothManagerPeripheralId"
private let myDesiredServiceId = CBUUID(string:
    "12345678-0000-0000-0000-000000000000")
private let myDesiredCharacteristicId = CBUUID(string:
    "12345678-0000-0000-0000-000000000000")
private let desiredManufacturerData = Data(base64Encoded: "foobar==")!
private let outOfRangeHeuristics: Set<CBError.Code> = [.unknown,
    .connectionTimeout, .peripheralDisconnected, .connectionFailed]

/// This manages a bluetooth peripheral. This is intended as a starting point
/// for you to customise from.
/// Read http://www.splinter.com.au/2019/05/18/ios-swift-bluetooth-le for a
/// background in how to set this all up.
class MyBluetoothManager {
    static let shared = MyBluetoothManager()
    
    let central = CBCentralManager(delegate: MyCentralManagerDelegate.shared,
        queue: nil, options: [
        CBCentralManagerOptionRestoreIdentifierKey: restoreIdKey,
        ])
    
    /// The 'state machine' for remembering where we're up to.
    var state = State.poweredOff
    enum State {
        case poweredOff
        case restoringConnectingPeripheral(CBPeripheral)
        case restoringConnectedPeripheral(CBPeripheral)
        case disconnected
        case scanning(Countdown)
        case connecting(CBPeripheral, Countdown)
        case discoveringServices(CBPeripheral, Countdown)
        case discoveringCharacteristics(CBPeripheral, Countdown)
        case connected(CBPeripheral)
        case outOfRange(CBPeripheral)
        
        var peripheral: CBPeripheral? {
            switch self {
            case .poweredOff: return nil
            case .restoringConnectingPeripheral(let p): return p
            case .restoringConnectedPeripheral(let p): return p
            case .disconnected: return nil
            case .scanning: return nil
            case .connecting(let p, _): return p
            case .discoveringServices(let p, _): return p
            case .discoveringCharacteristics(let p, _): return p
            case .connected(let p): return p
            case .outOfRange(let p): return p
            }
        }
    }
    
    // Begin scanning here!
    func scan() {
        guard central.state == .poweredOn else {
            print("Cannot scan, BT is not powered on")
            return
        }
        
        // Scan!
        central.scanForPeripherals(withServices: [myDesiredServiceId], options: nil)
        state = .scanning(Countdown(seconds: 10, closure: {
            self.central.stopScan()
            self.state = .disconnected
            print("Scan timed out")
        }))
    }
    
    /// Call this with forget: true to do a proper unpairing such that it won't
    /// try reconnect next startup.
    func disconnect(forget: Bool = false) {
        if let peripheral = state.peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        if forget {
            UserDefaults.standard.removeObject(forKey: peripheralIdDefaultsKey)
            UserDefaults.standard.synchronize()
        }
        state = .disconnected
    }

    func connect(peripheral: CBPeripheral) {
        // Connect!
        // Note: We're retaining the peripheral in the state enum because Apple
        // says: "Pending attempts are cancelled automatically upon
        // deallocation of peripheral"
        central.connect(peripheral, options: nil)
        state = .connecting(peripheral, Countdown(seconds: 10, closure: {
            self.central.cancelPeripheralConnection(peripheral)
            self.state = .disconnected
            print("Connect timed out")
        }))
    }
    
    func discoverServices(peripheral: CBPeripheral) {
        peripheral.delegate = MyPeripheralDelegate.shared
        peripheral.discoverServices([myDesiredServiceId])
        state = .discoveringServices(peripheral, Countdown(seconds: 10, closure: {
            self.disconnect()
            print("Could not discover services")
        }))
    }
    
    func discoverCharacteristics(peripheral: CBPeripheral) {
        guard let myDesiredService = peripheral.myDesiredService else {
            self.disconnect()
            return
        }
        peripheral.delegate = MyPeripheralDelegate.shared
        peripheral.discoverCharacteristics([myDesiredCharacteristicId],
            for: myDesiredService)
        state = .discoveringCharacteristics(peripheral, Countdown(seconds: 10,
            closure: {
            self.disconnect()
            print("Could not discover characteristics")
        }))
    }

    func setConnected(peripheral: CBPeripheral) {
        guard let myDesiredCharacteristic = peripheral.myDesiredCharacteristic
            else {
            print("Missing characteristic")
            disconnect()
            return
        }
        
        // Remember the ID for startup reconnecting.
        UserDefaults.standard.set(peripheral.identifier.uuidString,
            forKey: peripheralIdDefaultsKey)
        UserDefaults.standard.synchronize()

        // Ask for notifications when the peripheral sends us data.
        // TODO another state waiting for this?
        peripheral.delegate = MyPeripheralDelegate.shared
        peripheral.setNotifyValue(true, for: myDesiredCharacteristic)
        
        state = .connected(peripheral)
    }
    
    /// Write data to the peripheral.
    func write(data: Data) throws {
        guard case .connected(let peripheral) = state else {
            throw Errors.notConnected
        }
        guard let characteristic = peripheral.myDesiredCharacteristic else {
            throw Errors.missingCharacteristic
        }
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        // .withResponse is more expensive but gives you confirmation.
        // It's an exercise for the reader to ask for a response and handle
        // timeouts waiting for said response.
        // I found it simpler to deal with that at a higher level in a
        // messaging framework.
    }
    
    enum Errors: Error {
        case notConnected
        case missingCharacteristic
    }
    
}

extension CBPeripheral {
    /// Helper to find the service we're interested in.
    var myDesiredService: CBService? {
        guard let services = services else { return nil }
        return services.first { $0.uuid == myDesiredServiceId }
    }

    /// Helper to find the characteristic we're interested in.
    var myDesiredCharacteristic: CBCharacteristic? {
        guard let characteristics = myDesiredService?.characteristics else {
            return nil
        }
        return characteristics.first { $0.uuid == myDesiredCharacteristicId }
    }
}

class MyPeripheralDelegate: NSObject, CBPeripheralDelegate {
    static let shared = MyPeripheralDelegate()
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Ignore services discovered late.
        guard case .discoveringServices = MyBluetoothManager.shared.state else {
            return
        }
        
        if let error = error {
            print("Failed to discover services: \(error)")
            MyBluetoothManager.shared.disconnect()
            return
        }
        guard peripheral.myDesiredService != nil else {
            print("Desired service missing")
            MyBluetoothManager.shared.disconnect()
            return
        }
        
        // Progress to the next step.
        MyBluetoothManager.shared.discoverCharacteristics(peripheral: peripheral)
    }
    
    func peripheral(_ peripheral: CBPeripheral,
            didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Ignore characteristics arriving late.
        guard case .discoveringCharacteristics =
            MyBluetoothManager.shared.state else { return }
        
        if let error = error {
            print("Failed to discover characteristics: \(error)")
            MyBluetoothManager.shared.disconnect()
            return
        }
        guard peripheral.myDesiredCharacteristic != nil else {
            print("Desired characteristic missing")
            MyBluetoothManager.shared.disconnect()
            return
        }

        // Ready to go!
        MyBluetoothManager.shared.setConnected(peripheral: peripheral)
    }
    
    func peripheral(_ peripheral: CBPeripheral,
            didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error)
            return
        }

        // This is where the peripheral sends you data!
        // Exercise for the reader: handle the characteristic.value, eg buffer
        // and scan for JSON between STX and ETX markers.
    }
    
    /// Called when .withResponse is used.
    func peripheral(_ peripheral: CBPeripheral,
            didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error)")
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
            didUpdateNotificationStateFor characteristic: CBCharacteristic,
            error: Error?) {
        // TODO cancel a setNotifyValue timeout if no error.
    }
}

class MyCentralManagerDelegate: NSObject, CBCentralManagerDelegate {
    static let shared = MyCentralManagerDelegate()
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Are we transitioning from BT off to BT ready?
            if case .poweredOff = MyBluetoothManager.shared.state {
                // Firstly, try to reconnect:
                if let peripheralIdStr = UserDefaults.standard
                        .object(forKey: peripheralIdDefaultsKey) as? String,
                    let peripheralId = UUID(uuidString: peripheralIdStr),
                    let previouslyConnected = central
                        .retrievePeripherals(withIdentifiers: [peripheralId])
                        .first {
                    MyBluetoothManager.shared.connect(
                        peripheral: previouslyConnected)
                    
                    // Next, try for ones that are connected to the system:
                } else if let systemConnected = central
                        .retrieveConnectedPeripherals(withServices:
                        [myDesiredServiceId]).first {
                    MyBluetoothManager.shared.connect(peripheral: systemConnected)

                } else {
                    // Not an error, simply the case that they've never paired
                    // before, or they did a manual unpair:
                    MyBluetoothManager.shared.state = .disconnected
                }
            }
            
            // Did CoreBluetooth wake us up with a peripheral that was connecting?
            if case .restoringConnectingPeripheral(let peripheral) =
                    MyBluetoothManager.shared.state {
                MyBluetoothManager.shared.connect(peripheral: peripheral)
            }
            
            // CoreBluetooth woke us with a 'connected' peripheral, but we had
            // to wait until 'poweredOn' state:
            if case .restoringConnectedPeripheral(let peripheral) =
                    MyBluetoothManager.shared.state {
                if peripheral.myDesiredCharacteristic == nil {
                    MyBluetoothManager.shared.discoverServices(
                        peripheral: peripheral)
                } else {
                    MyBluetoothManager.shared.setConnected(peripheral: peripheral)
                }
            }
        } else { // Turned off.
            MyBluetoothManager.shared.state = .poweredOff
        }
    }
    
    // Apple says: This is the first method invoked when your app is relaunched
    // into the background to complete some Bluetooth-related task.
    func centralManager(_ central: CBCentralManager,
            willRestoreState dict: [String : Any]) {
        let peripherals: [CBPeripheral] = dict[
            CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        if peripherals.count > 1 {
            print("Warning: willRestoreState called with >1 connection")
        }
        // We have a peripheral supplied, but we can't touch it until
        // `central.state == .poweredOn`, so we store it in the state
        // machine enum for later use.
        if let peripheral = peripherals.first {
            switch peripheral.state {
            case .connecting: // I've only seen this happen when
                // re-launching attached to Xcode.
                MyBluetoothManager.shared.state =
                    .restoringConnectingPeripheral(peripheral)

            case .connected: // Store for connection / requesting
                // notifications when BT starts.
                MyBluetoothManager.shared.state =
                    .restoringConnectedPeripheral(peripheral)
            default: break
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
            didDiscover peripheral: CBPeripheral,
            advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard case .scanning = MyBluetoothManager.shared.state else { return }
        
        // You might want to skip this manufacturer data check.
        guard let mfgData =
                advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
            mfgData == desiredManufacturerData else {
            print("Missing/wrong manufacturer data")
            return
        }
        
        central.stopScan()
        MyBluetoothManager.shared.connect(peripheral: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager,
            didConnect peripheral: CBPeripheral) {
        if peripheral.myDesiredCharacteristic == nil {
            MyBluetoothManager.shared.discoverServices(peripheral: peripheral)
        } else {
            MyBluetoothManager.shared.setConnected(peripheral: peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager,
            didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MyBluetoothManager.shared.state = .disconnected
    }
    
    func centralManager(_ central: CBCentralManager,
            didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Did our currently-connected peripheral just disconnect?
        if MyBluetoothManager.shared.state.peripheral?.identifier ==
                peripheral.identifier {
            // IME the error codes encountered are:
            // 0 = rebooting the peripheral.
            // 6 = out of range.
            if let error = error,
                (error as NSError).domain == CBErrorDomain,
                let code = CBError.Code(rawValue: (error as NSError).code),
                outOfRangeHeuristics.contains(code) {
                // Try reconnect without setting a timeout in the state machine.
                // With CB, it's like saying 'please reconnect me at any point
                // in the future if this peripheral comes back into range'.
                MyBluetoothManager.shared.central.connect(peripheral, options: nil)
                MyBluetoothManager.shared.state = .outOfRange(peripheral)
            } else {
                // Likely a deliberate unpairing.
                MyBluetoothManager.shared.state = .disconnected
            }
        }
    }
}

/// Timer wrapper that automatically invalidates when released.
/// Read more: http://www.splinter.com.au/2019/03/28/timers-without-circular-references-with-pendulum
class Countdown {
    let timer: Timer
    
    init(seconds: TimeInterval, closure: @escaping () -> ()) {
        timer = Timer.scheduledTimer(withTimeInterval: seconds,
                repeats: false, block: { _ in
            closure()
        })
    }
    
    deinit {
        timer.invalidate()
    }
}
