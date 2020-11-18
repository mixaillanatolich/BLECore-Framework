//
//  BLEResponseFactory.swift
//  BLECore
//
//  Created by Mixaill on 13.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation

class BLEResponseFactory: NSObject {
    
    func handleResponse(_ command: BLECommand) {
        if !command.handleResponse() {
            command.response = BLEResponse(rawData: command.rawResponse)
        }
    }
    
    func handleResponse(rawData: Data) -> BLEResponse? {
        return nil
    }
    
    func handleNotificationRawResponse(rawData: Data) -> BLEResponse? {
        return nil
    }
    
    func handleNotificationResponse(message: BLEResponse) {
    }
}
