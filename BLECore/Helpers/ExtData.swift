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
}
