//
//  BLEDevicePeripheral.swift
//  BLECore
//
//  Created by Mixaill on 12.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation
import CoreBluetooth


public class BLEDevicePeripheral: NSObject {

    fileprivate var peripheral: CBPeripheral
    
    fileprivate var responseBuf = Data()
     
    //TODO maybe create a model with expected service and characteristics into it
    
    fileprivate var serviceUUIDs = [CBUUID]()
    fileprivate var cbServices: [CBService]?
    
    fileprivate var characteristicsUUIDs = [CBUUID]()
    fileprivate var cbCharacteristics: [CBCharacteristic]?
    
    fileprivate var responseFactory = BLEResponseFactory()
     
    fileprivate var timeoutWorkItem: DispatchWorkItem?
    
    fileprivate var communicationThread = DispatchQueue(label: "com.m-technologies.bluetooth.communication", attributes: DispatchQueue.Attributes.concurrent)
     
    fileprivate var isWaitingFinishCurrentCommand = false
    
    let sendCommandDispatchGroup = DispatchGroup()
    let sendCommandDispatchSemaphore = DispatchSemaphore(value: 0)
     
    fileprivate var commands:[BLECommand] = [] {
        didSet {
            // Confirm there are commands to send, and we aren't waiting on confirming a command was sent.
            if isWaitingFinishCurrentCommand && (timeoutWorkItem == nil || timeoutWorkItem!.isCancelled) {
                isWaitingFinishCurrentCommand = false
            }
            
            if let command = commands.first, !isWaitingFinishCurrentCommand {
                sendCommand(command)
            }
        }
    }
    
    init(initWith cbPeripheral: CBPeripheral, serviceIds: [CBUUID], characteristicIds: [CBUUID]) {
        peripheral = cbPeripheral
        super.init()
        peripheral.delegate = self
        
        responseFactory = BLEResponseFactory()

        serviceUUIDs = serviceIds
        
        characteristicsUUIDs = characteristicIds
    }
    
    deinit {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        self.reset()
    }
    
    func reset() {
        for command in commands {
            command.status = .fail
            command.error = BLEError.communication(type: .reseted)
            command.sendCallback()
        }
        commands.removeAll()
        self.peripheral.delegate = nil
    }
    
    func startDiscoveringServices() {
        self.peripheral.discoverServices(serviceUUIDs)
    }
    
    public func addCommandToQueue(_ command:BLECommand, highProirity: Bool = false) {
        guard peripheral.state == .connected else {
            dLog("Unable to add command at this time, peripheral is not connected.")
            command.error = BLEError.communication(type: .disconnected)
            command.status = .fail
            command.sendCallback()
            return
        }
         
         DispatchQueue.main.async {
             if highProirity && self.commands.count > 1 {
                 self.commands.insert(command, at: 1)
             } else {
                 self.commands.append(command)
             }
         }
         
    }
    
    fileprivate func isCompletelyConnected() -> Bool {
        if peripheral.state == .connected {
            return discoveryCompleted()
        }
        return false
    }
    
    fileprivate func discoveryCompleted() -> Bool {
        if cbServices != nil && cbServices!.count == serviceUUIDs.count
            && cbCharacteristics != nil && cbCharacteristics!.count == characteristicsUUIDs.count {
            return true
        }
        return false
    }
     
    fileprivate func setRequestTimeout(timeout: TimeInterval) {
        timeoutWorkItem = DispatchWorkItem {
            guard let item = self.timeoutWorkItem, !item.isCancelled else {
                return
            }
            self.requestTimeout()
        }
        communicationThread.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem!)
    }
    
    fileprivate func sendCommand(_ command: BLECommand) {
        guard !isWaitingFinishCurrentCommand else {
            return
        }
         
        isWaitingFinishCurrentCommand = true
        
        communicationThread.async {
            self.sendRequest(command)
        }
    }
     
    fileprivate func sendRequest(_ command: BLECommand) {
         
        let request: BLERequest = command.request
         
        setRequestTimeout(timeout: TimeInterval(request.timeout))
         
        if request.mode == .read {
            dLog("read Characteristic: \(request.requestCharacteristicId)")
            self.peripheral.readValue(for: cbCharacteristic(with: request.requestCharacteristicId)!)
        } else if request.mode == .write {
            
            let payloads: [Data] = request.rawData()
            
            for aPayload in payloads {
                dLog("writeValue: \(aPayload as NSData) forCharacteristic: \(request.requestCharacteristicId)")
                //dLog("timeout: \(command.request.timeout)")
                self.peripheral.writeValue(aPayload,
                                           for: cbCharacteristic(with: request.requestCharacteristicId)!,
                                           type: request.isWriteWithResponse ? CBCharacteristicWriteType.withResponse : CBCharacteristicWriteType.withoutResponse)
                
                dLog("waiting send command")
                let timeoutResult = sendCommandDispatchSemaphore.wait(timeout: .now() + 1.0)
                dLog("command should be sent")
                
                if timeoutResult == .timedOut {
                    timeoutWorkItem?.cancel()
                    communicationThread.async {
                        self.requestTimeout()
                    }
                    return
                }
                
//                if payloads.count > 1 {
//                    // Thread.sleep(until: Date(timeIntervalSinceNow: 0.01)) for FW upgrade
//                    Thread.sleep(until: Date(timeIntervalSinceNow: command.request.sendPayloadTimeout))
//                }
            }
              
            if (!request.isWriteWithResponse && !request.isWaitResponse) {
                command.status = .success
                finishRequest(for: command)
            }
        }
    }
     
    fileprivate func requestTimeout() {
         
        guard let command = commands.first else {
            return
        }
         
        if command.request.retryCount > 0 {
            command.request.retryCount -= 1
            dLog("attemptCount: \(command.request.retryCount)")
            isWaitingFinishCurrentCommand = false
            
            guard !commands.isEmpty else {
                return
            }
            
            addCommandToQueue(command, highProirity: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.isWaitingFinishCurrentCommand = false
                self.commands.removeFirst()
            }
            
            return
        }
         
        command.error = BLEError.communication(type: .timeout)
        command.status = .requestTimeout
        command.sendCallback()
        isWaitingFinishCurrentCommand = false
        
        guard !commands.isEmpty else {
            return
        }
        
        commands.removeFirst()
         
     }
    
    fileprivate func finishRequest(for command: BLECommand) {
        isWaitingFinishCurrentCommand = false
        timeoutWorkItem?.cancel()
        if !commands.isEmpty {
            commands.removeFirst()
        }
        command.sendCallback()
    }
    
    fileprivate func cbCharacteristic(with uuid: String) -> CBCharacteristic? {
        return cbCharacteristics?.filter({ (cbCharacteristic) -> Bool in
            return cbCharacteristic.uuid.uuidString.lowercased().contains(uuid.lowercased())
            }).first
    }
}



extension BLEDevicePeripheral: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        dLog("didModifyServices")
    }
        
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        dLog("didDiscoverServices")
        dLog("peripheral.services \(peripheral.services.orNil)")
        dLog("deviceServiceUUID \(serviceUUIDs)")
        dLog("error discovering services: \(error.orNil)")
        
        if error != nil {
            BLEManager.relayDeviceConnectStatus(.error, BLEError.connection(type: .missedServices))
            BLEManager.disconectFromDevice()
            return
        }
        
        guard let services = peripheral.services, !services.isEmpty else {
            BLEManager.relayDeviceConnectStatus(.error, BLEError.connection(type: .missedServices))
            BLEManager.disconectFromDevice()
            return
        }
        
        cbServices = [CBService]()
        cbCharacteristics = [CBCharacteristic]()
        for pService in services {
            if serviceUUIDs.contains(pService.uuid) {
                cbServices!.append(pService)
            }
        }
        
        guard !cbServices!.isEmpty else {
            BLEManager.relayDeviceConnectStatus(.error, BLEError.connection(type: .missedServices))
            BLEManager.disconectFromDevice()
            return
        }
        
        for cbService in cbServices! {
            peripheral.discoverCharacteristics(characteristicsUUIDs, for: cbService)
        }
    }
        
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        dLog("didDiscoverCharacteristicsForService")
        dLog("error discovering characteristics: \(error.orNil)")
        
        if error != nil {
            BLEManager.relayDeviceConnectStatus(.error, BLEError.connection(type: .missedCharacteristics))
            BLEManager.disconectFromDevice()
            return
        }
        
        guard serviceUUIDs.contains(service.uuid) else {
            return
        }
        
        if let characteristics = service.characteristics {
            for aCharacteristic in characteristics {
                if characteristicsUUIDs.contains(aCharacteristic.uuid) {
                    cbCharacteristics?.append(aCharacteristic)
                    if aCharacteristic.properties.contains(.notify) {
                        peripheral.setNotifyValue(true, for: aCharacteristic)
                    }
                }
            }
        }
        
        if isCompletelyConnected() {
            BLEManager.resetConnectionTimeout()
            BLEManager.relayDeviceConnectStatus(.ready, nil)
        }
            
    }
        
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        dLog("didUpdateValueForCharacteristic: \(characteristic.uuid.uuidString), error: \(error.orNil)")
        dLog("characteristic.value: \((characteristic.value as NSData?).orNil)")
        
        guard let command = commands.first else {
            return
        }
        
        guard characteristic.uuid.uuidString.lowercased().contains(command.request.responseCharacteristicId.lowercased()) else {
            dLog("WTF2 \(command.request.responseCharacteristicId)")
            return
        }
        
        if let error = error {
            command.error = BLEError.communication(type: .updateCharacteristicValue(error: error))
            command.status = .fail
            finishRequest(for: command)
        }
        
        if command.request.isWaitResponse {
            command.status = .success
            command.rawResponse = characteristic.value ?? Data()
            responseFactory.handleResponse(command)
            finishRequest(for: command)
        }
    }
        
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        dLog("didWriteValueForCharacteristic: \(characteristic.uuid.uuidString), error: \(error.orNil)")
            
        sendCommandDispatchSemaphore.signal()
        
        guard let command = commands.first else {
            return
        }
        
        guard characteristic.uuid.uuidString.lowercased().contains(command.request.responseCharacteristicId.lowercased()) else {
            dLog("WTF3 \(command.request.responseCharacteristicId)")
            return
        }

        if let error = error {
            command.error = BLEError.communication(type: .writeCharacteristicValue(error: error))
            command.status = .fail
            finishRequest(for: command)
            return
        }
        
        if !command.request.isWaitResponse {
            command.status = .success
            finishRequest(for: command)
            return
        }
        
       // peripheral.readValue(for: characteristic)
    }
        
    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        dLog("peripheralIsReadyq")
        sendCommandDispatchSemaphore.signal()
    }
}
