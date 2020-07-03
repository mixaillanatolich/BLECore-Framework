//
//  ExtData.swift
//  BLECore
//
//  Created by Mixaill on 14.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation

extension Data {
    
    func hexadecimal() -> String {
        return map { String(format: "%02x", $0) }
            .joined(separator: "")
    }
    
    func uint16() -> UInt16 {
//        let array = Array(self)
//        let unicastUInt16 : UInt16 = UnsafePointer(array).withMemoryRebound(to: UInt16.self, capacity: 1) {
//            $0.pointee
//        }
//        return unicastUInt16
        return withUnsafeBytes { $0.bindMemory(to: UInt16.self) }[0]
    }

    func uint8() -> UInt8 {
        let array = Array(self)
        return array[0]
    }
}
