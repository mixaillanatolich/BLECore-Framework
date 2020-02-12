//
//  BLEPeripheral.swift
//  BLECore
//
//  Created by Mixaill on 12.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation
import CoreBluetooth

public class BLEPeripheral {

    var peripheral: CBPeripheral
    var advertisementData: [String : Any]
    var rssi: NSNumber
    
    init(with peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = RSSI
    }
    
    func uuid() -> String {
        return peripheral.identifier.uuidString
    }
    
}
