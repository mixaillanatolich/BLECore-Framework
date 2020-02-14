//
//  GyverRequest.swift
//  BLECore
//
//  Created by Mixaill on 14.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import UIKit

class GyverRequest: BLERequest {

    init(request: String, requestCharacteristic: String, responseCharacteristic: String) {
        super.init(requestCharacteristic: requestCharacteristic, responseCharacteristic: responseCharacteristic)
        data = request.hexData()
    }
    
    override init(rawData: Data?, requestCharacteristic: String, responseCharacteristic: String) {
        super.init(requestCharacteristic: requestCharacteristic, responseCharacteristic: responseCharacteristic)
        if let rawData = rawData {
            data = rawData
        }
    }
    
    override func rawData() -> [Data] {
        var requestData = Data()
        requestData.append("S".hexData())
        requestData.append(data)
        requestData.append(";".hexData())
        return [requestData]
    }
    
}
