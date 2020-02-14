//
//  BLERequest.swift
//  BLECore
//
//  Created by Mixaill on 13.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation
import CoreBluetooth

enum BLERequestMode: Int {
    case read
    case write
}

class BLERequest: NSObject {
    var requestCharacteristic: CBCharacteristic
    var responseCharacteristic: CBCharacteristic
    var mode:BLERequestMode = .read
    var isWaitResponse = false
    var isWriteWithResponse = true
    var data = [Data()]
    var timeout: Int = 10
    var retryCount: Int = 0
    
    init (requestCharacteristic: CBCharacteristic, responseCharacteristic: CBCharacteristic) {
        self.requestCharacteristic = requestCharacteristic
        self.responseCharacteristic = responseCharacteristic
    }
    
    init(rawData: [Data]?, requestCharacteristic: CBCharacteristic, responseCharacteristic: CBCharacteristic) {
        self.requestCharacteristic = requestCharacteristic
        self.responseCharacteristic = responseCharacteristic
        if let rawData = rawData {
            data = rawData
        }
    }
    
    func rawData() -> [Data] {
        return data
    }
    
    func handleRawResponse(_ rawResponse: Data) -> (Bool, BLEResponse?) {
        return (true, nil)
    }
}
