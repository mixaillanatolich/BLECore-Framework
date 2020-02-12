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

    var peripheral: CBPeripheral
     
     var serviceUUID = CBUUID.init(string: "0000")
     var service: CBService?
     
     var characteristicsForDiscover = [CBUUID]()
     
     //var responseFactory = NRFMeshResponseFactory()
     
     //var alreadyCompletelyConnected = false
     
    // let requestTimeoutValue = 25
     //var timeoutTimer: Timer?
     
     //var pendingSuccessfulCommand = false
    
    init(initWith cbPeripheral: CBPeripheral!) {
        peripheral = cbPeripheral
        super.init()
        peripheral.delegate = self
    }
    
    
    func startDiscoveringServices() {
        
    }
    
    func reset() {
        
    }
}


extension BLEDevicePeripheral: CBPeripheralDelegate {
    
}
