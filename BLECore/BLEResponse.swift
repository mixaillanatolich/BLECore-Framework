//
//  BLEResponse.swift
//  BLECore
//
//  Created by Mixaill on 13.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation

public class BLEResponse: NSObject {
    var data: Data?
    var dataArray: [UInt8]?
    
    init?(rawData: Data?) {
        super.init()
        self.data = rawData
        toUInt8Array()
    }
    
    func dataAsString() -> String? {
        guard let data = data else {
            return nil
        }
        
        return String(data: data, encoding: String.Encoding.ascii)
    }
    
    fileprivate func toUInt8Array() {
        
        guard let data = data else {
            return
        }
        
        guard data.count > 0 else {
            return
        }
        
        self.dataArray = [UInt8](data)
        dLog("response arr: \(self.dataArray.orNil)")
    }
}
