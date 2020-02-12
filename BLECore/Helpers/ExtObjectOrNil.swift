//
//  ObjectOrNil.swift
//
//  Created by Mikhail Muravev on 11/01/2019.
//  Copyright © 2019 M-Technology. All rights reserved.
//

import Foundation

extension Optional {
    var orNil : String {
        if self == nil {
            return "nil"
        }
        if "\(Wrapped.self)" == "String" {
            return "\"\(self!)\""
        }
        return "\(self!)"
    }
    
    var orEmpty : String {
        if self == nil {
            return ""
        }
        return "\(self!)"
    }
}
