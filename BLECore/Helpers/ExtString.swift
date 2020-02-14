//
//  ExtString.swift
//  BLECore
//
//  Created by Mixaill on 14.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation

extension String {
    
    func hexadecimalData() -> Data? {
        var data = Data(capacity: self.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, options: [], range: NSMakeRange(0, self.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else {
            return nil
        }
        
        return data
    }
    
    func hexData() -> Data {
        return data(using: .utf8) ?? Data()
    }
    
    func hexadecimalString() -> String? {
        return data(using: .utf8)?
            .hexadecimal()
    }

}

