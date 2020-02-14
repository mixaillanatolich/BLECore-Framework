//
//  BLECommand.swift
//  BLECore
//
//  Created by Mixaill on 13.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation

enum BLECommandStatus: String {
    case unknown
    case success
    case fail
    case waiting
    case requestTimeout
}

typealias ResponseCallbackClosure = (BLECommandStatus, BLEResponse?, BLEError?) -> Void

class BLECommand: NSObject {
    var request: BLERequest
    var response: BLEResponse?
    var rawResponse: Data = Data()
    var status:BLECommandStatus = .unknown
    var error: BLEError?
    
    var responseCallback: ResponseCallbackClosure?
    
    init(deviceRequest: BLERequest) {
        request = deviceRequest
    }
    
    func handleResponse() -> Bool {
        let (status, response) = request.handleRawResponse(rawResponse)
        self.response = response
        return !status
    }
    
    func sendCallback() {
        guard let callback = responseCallback else {
            return
        }
        
        callback(status, response, error)
    }
}
