//
//  BLECentralManager.swift
//  BLECore
//
//  Created by Mixaill on 12.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation
import CoreBluetooth

public enum BLEDeviceConnectStatus: String {
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

    fileprivate var serviceDiscoverUUIDs: [CBUUID]? //= [CBUUID.init(string: "0000")]
   // fileprivate var serviceUUIDs: [CBUUID]? = [CBUUID(string: "1827"), CBUUID(string: "1828")]
    
    fileprivate var serviceUUIDs = [CBUUID]()
    fileprivate var characteristicsUUIDs = [CBUUID]()
    
    fileprivate var discoveredDevices = NSMutableSet()
    
    public typealias DiscoveryDeviceCallbackClosure = (_ isNewDevice: Bool, _ device: BLEPeripheral) -> Void
    fileprivate var discoveryDeviceCallback: DiscoveryDeviceCallbackClosure?
    
    public typealias DeviceConnectStatusCallbackClosure = (_ status: BLEDeviceConnectStatus, _ device: CBPeripheral?, _ deviceType: BLEDeviceType, _ error: BLEError?) -> Void
    fileprivate var deviceConnectStatusCallback: DeviceConnectStatusCallbackClosure?
    
    fileprivate var timeoutWorkItem: DispatchWorkItem?
    
    var currentDevice: BLEDevicePeripheral? {
        didSet {
            if let device = self.currentDevice {
                //TODO add timer
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
        
        self.serviceDiscoverUUIDs = serviceUUIDs
        
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
    
    public func connectToDevice(_ peripheral: CBPeripheral, deviceType: BLEDeviceType, serviceIds: [CBUUID], characteristicIds: [CBUUID], timeout: TimeInterval? = nil) {
        // If not already connected to a peripheral, then connect to this one
        if ((self.peripheral == nil) || (self.peripheral?.state == CBPeripheralState.disconnected)) {
            
            // Retain the peripheral before trying to connect
            self.peripheral = peripheral
            
            self.serviceUUIDs = serviceIds
            self.characteristicsUUIDs = characteristicIds
            
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
    
    public func isDiscovering() -> Bool {
        return isScanning
    }
    
    func resetConnectionTimeout() {
        timeoutWorkItem?.cancel()
    }
    
    func relayDeviceConnectStatus(_ status: BLEDeviceConnectStatus, _ error: BLEError?) {
        deviceConnectStatusCallback?(status, peripheral, deviceType, error)
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
           // timeoutWorkItem?.cancel()
            
            self.currentDevice = BLEDevicePeripheral(initWith: peripheral, serviceIds: serviceUUIDs, characteristicIds: characteristicsUUIDs)
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
            
            deviceConnectStatusCallback?(.error, peripheral, deviceType, BLEError.connection(type: .failToConnect))
        }
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        dLog("\(dict)")
    }
}

extension BLECentralManager {
    
    fileprivate func connectionTimeout() {
        
        guard let peripheral = self.peripheral else {
            return
        }
        
        guard peripheral.state == .connecting || peripheral.state == .connected else {
            return
        }
            
        centralManager?.cancelPeripheralConnection(peripheral)
        
        self.currentDevice = nil;
        self.peripheral?.delegate = nil
        self.peripheral = nil;
        
        deviceConnectStatusCallback?(.timeoutError, peripheral, deviceType, BLEError.connection(type: .connectionTimeout))
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
            centralManager?.scanForPeripherals(withServices: serviceDiscoverUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    fileprivate func stopScanDevices() {
        if isScanning && isPowerOn {
            dLog("Stop ble scan")
            centralManager?.stopScan()
        }
    }
    
}
