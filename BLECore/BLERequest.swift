//
//  BLERequest.swift
//  BLECore
//
//  Created by Mixaill on 13.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation
import CoreBluetooth

public enum BLERequestMode: Int {
    case read
    case write
}

public class BLERequest: NSObject {
    var requestCharacteristicId: String
    var responseCharacteristicId: String
    var mode:BLERequestMode = .read
    var isWaitResponse = false
    var isWriteWithResponse = true
    var data = Data()
    var timeout: Int = 10
    var sendPayloadTimeout: TimeInterval = 0.01
    var retryCount: Int = 0
    
    init(requestCharacteristic: String, responseCharacteristic: String) {
        self.requestCharacteristicId = requestCharacteristic
        self.responseCharacteristicId = responseCharacteristic
    }
    
    init(rawData: Data?, requestCharacteristic: String, responseCharacteristic: String) {
        self.requestCharacteristicId = requestCharacteristic
        self.responseCharacteristicId = responseCharacteristic
        if let rawData = rawData {
            data = rawData
        }
    }
    
    func rawData() -> [Data] {
        return [data]
    }
    
}
