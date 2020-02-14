//
//  BLEDevicePeripheral.swift
//  BLECore
//
//  Created by Mixaill on 12.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation
import CoreBluetooth


class BLEDevicePeripheral: NSObject {

    fileprivate var peripheral: CBPeripheral
    
    fileprivate var responseBuf = Data()
     
    fileprivate var serviceUUIDs = [CBUUID]()
    fileprivate var cbServices: [CBService]?
    
    fileprivate var characteristicsUUIDs = [CBUUID]()
    fileprivate var cbCharacteristic: [CBCharacteristic]?
    
    fileprivate var responseFactory = BLEResponseFactory()
     
    fileprivate var timeoutWorkItem: DispatchWorkItem?
    
    fileprivate var communicationThread = DispatchQueue(label: "com.m-technologies.bluetooth.communication", attributes: DispatchQueue.Attributes.concurrent)
     
    fileprivate var isWaitingFinishCurrentCommand = false
     
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
    
    func isCompletelyConnected() -> Bool {
        if peripheral.state == .connected {
            return discoveryCompleted()
        }
        return false
    }
    
    fileprivate func discoveryCompleted() -> Bool {
        if cbServices != nil && cbServices!.count == serviceUUIDs.count
            && cbCharacteristic != nil && cbCharacteristic!.count == characteristicsUUIDs.count {
            return true
        }
        return false
    }
    
    
    func addCommandToQueue(_ command:BLECommand, highProirity: Bool = false) {
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
     
    fileprivate func sendCommand(_ command: BLECommand) {
        guard !isWaitingFinishCurrentCommand else {
            return
        }
         
        isWaitingFinishCurrentCommand = true
        
        sendRequest(command)
    }
     
    fileprivate func sendRequest(_ command: BLECommand) {
         
        let request: BLERequest = command.request
         
        timeoutWorkItem?.cancel()
        timeoutWorkItem = DispatchWorkItem {
            guard let item = self.timeoutWorkItem, !item.isCancelled else {
                return
            }
            self.requestTimeout()
        }
        communicationThread.asyncAfter(deadline: .now() + TimeInterval(request.timeout), execute: timeoutWorkItem!)
         
        if request.mode == .read {
            dLog("read Characteristic: \(request.requestCharacteristic)")
            self.peripheral.readValue(for: request.requestCharacteristic)
        } else {
            //TODO: refactor this shit
            let payloads: [Data] = request.rawData()
            
            for aPayload in payloads {
                dLog("writeValue: \(aPayload as NSData) forCharacteristic: \(request.requestCharacteristic.uuid.uuidString)")
                //dLog("timeout: \(command.request.timeout)")
                self.peripheral.writeValue(aPayload,
                                           for: request.requestCharacteristic,
                                           type: request.isWriteWithResponse ? CBCharacteristicWriteType.withResponse : CBCharacteristicWriteType.withoutResponse)
                if payloads.count > 1 {
                   // Thread.sleep(until: Date(timeIntervalSinceNow: 0.01)) for FW upgrade
                    //Thread.sleep(until: Date(timeIntervalSinceNow: command.request.payloadTimeout))
                   Thread.sleep(until: Date(timeIntervalSinceNow: 0.01))
                }
            }
              
            if (!request.isWriteWithResponse && !request.isWaitResponse) {
                command.status = .success
                isWaitingFinishCurrentCommand = false
                if commands.count > 0 {
                    commands.removeFirst()
                }
                
                timeoutWorkItem?.cancel()
                command.sendCallback()
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
            
            timeoutWorkItem?.cancel()
            
            guard commands.first != nil else {
                return
            }
            
            commands.removeFirst()
            
            addCommandToQueue(command)
            
            return
        }
         
        command.error = BLEError.communication(type: .timeout)
        command.status = .requestTimeout
        command.sendCallback()
        isWaitingFinishCurrentCommand = false
        
        timeoutWorkItem?.cancel()
        
        guard commands.first != nil else {
            return
        }
        
        commands.removeFirst()
         
     }
}



extension BLEDevicePeripheral: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        dLog("didModifyServices")
    }
        
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
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
        cbCharacteristic = [CBCharacteristic]()
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
        
//        let deviceCBServices = peripheral.services?.filter({argService in argService.uuid == serviceUUIDs})
//        deviceCBService = deviceCBServices?.first
//
//        if cbServices != nil {
//            peripheral.discoverCharacteristics(characteristicsToDiscover, for: cbServices!)
//        } else {
//            dLog("missing service")
//            BLEManager.disconectFromDevice()
//        }
    }
        
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
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
        
        //TODO: refactor 
        if let characteristics = service.characteristics {
            for aCharacteristic in characteristics {
                if characteristicsUUIDs.contains(aCharacteristic.uuid) {
                    cbCharacteristic?.append(aCharacteristic)
                    peripheral.setNotifyValue(true, for: aCharacteristic)
                }
            }
        }
        
        if isCompletelyConnected() {
            BLEManager.resetConnectionTimeout()
            BLEManager.relayDeviceConnectStatus(.ready, nil)
        }
            
    }
        
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        dLog("didUpdateValueForCharacteristic: \(characteristic.uuid.uuidString), error: \(error.orNil)")
        
        guard let command = commands.first else {
            return
        }
        
        guard command.request.responseCharacteristic == characteristic else {
            dLog("WTF2 \(command.request.responseCharacteristic)")
            return
        }
        
        if let error = error {
            command.error = BLEError.communication(type: .updateCharacteristicValue(error: error))
            command.status = .fail
            isWaitingFinishCurrentCommand = false
            timeoutWorkItem?.cancel()
            
            commands.removeFirst()
            command.sendCallback()
        }
        
        if command.request.isWaitResponse {
            command.status = .success
            dLog("characteristic.value: \((characteristic.value as NSData?).orNil)")
            command.rawResponse = characteristic.value ?? Data()
            responseFactory.handleResponse(command)
            isWaitingFinishCurrentCommand = false
            
            timeoutWorkItem?.cancel()
            
            commands.removeFirst()
            command.sendCallback()
        }
            
//        dLog( "Charactertic: \(characteristic.uuid.uuidString)")
//
//        guard let value = characteristic.value else {
//            dLog("got empty msg")
//            return
//        }
//
//        dLog( "got msg: \(value.hexadecimalString())")
//
//        guard let command = commands.first else {
//            dLog("got notification message")
//            if let message = responseFactory.handleResponse(rawData: value) {
//                responseFactory.handleNotificationResponse(message: message)
//            }
//            return
//        }
//
//        if let error = error {
//            command.error = BLEError.communication(type: .updateCharacteristicValue(error: error))
//            command.status = .fail
//            isWaitingFinishCurrentCommand = false
//            timeoutWorkItem?.cancel()
//
//            commands.removeFirst()
//            command.sendCallback()
//        }
//
//                    /*
//                    // Handle notification messages during wait other responses
//                   if let message = responseFactory.handleResponse(rawData: value) {
//                        responseFactory.handleNotificationResponse(message: message)
//                    }
//                    */
//
//        if command.request.isWaitResponse {
//
//            command.rawResponse = value
//
//            let needWait = command.handleResponse()
//
//            if needWait {
//                if let message = responseFactory.handleNotificationResponse(rawData: value) {
//                    dLog("got notification message2")
//                    responseFactory.handleNotificationResponse(message: message)
//                }
//                return
//            }
//
//            command.status = .success
//            isWaitingFinishCurrentCommand = false
//
//            timeoutWorkItem?.cancel()
//
//            if let aCommand = commands.first {
//                if aCommand == command {
//                    commands.removeFirst()
//                } else {
//                    dLog("remove cmd error")
//                }
//            } else {
//                dLog("remove cmd error")
//            }
//            command.sendCallback()
//        }
            
            
    }
        
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            //dLog("didWriteValueForCharacteristic: \(characteristic.uuid.uuidString), error: \(error.orNil)")
            
        guard let command = commands.first else {
            return
        }
        
        guard command.request.responseCharacteristic == characteristic else {
            dLog("WTF3 \(command.request.responseCharacteristic.uuid.uuidString)")
            return
        }

        if let error = error {
            command.error = BLEError.communication(type: .writeCharacteristicValue(error: error))
            command.status = .fail
            isWaitingFinishCurrentCommand = false
            
            timeoutWorkItem?.cancel()
            
            commands.removeFirst()
            command.sendCallback()
            return
        }
        
        if !command.request.isWaitResponse {
            command.status = .success
            isWaitingFinishCurrentCommand = false
            
            commands.removeFirst()
            
            timeoutWorkItem?.cancel()
            command.sendCallback()
            return
        }
        
        peripheral.readValue(for: characteristic)
    }
        
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
            //dLog("peripheralIsReadyq")

            
    //        guard let command = commandQueue.first else {
    //            return
    //        }
    //
    //        dLog("\(timeoutTimer.orNil)")
    //
    //        if !command.request.waitResponse {
    //            command.commandStatus = .success
    //            pendingSuccessfulCommand = false
    //
    //            commandQueue.removeFirst()
    //
    //            timeoutTimer?.invalidate()
    //            timeoutTimer = nil
    //            dLog("\(timeoutTimer.orNil)")
    //            command.sendCallback()
    //        }
    //
    //        dLog("\(timeoutTimer.orNil)")
    }
}
