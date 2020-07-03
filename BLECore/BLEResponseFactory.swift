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
//        if rawResponse[0] & 0xC0 == 0x40 {
//            if lastMessageType == 0x40 {
//                //Drop repeated 0x40's
//                dLog("CMP:Reduntand SAR start, dropping")
//                segmentedData = Data()
//            }
//            lastMessageType = 0x40
//            //Add message type header
//            segmentedData.append(Data([rawResponse[0] & 0x3F]))
//            segmentedData.append(Data(rawResponse.dropFirst()))
//        } else if rawResponse[0] & 0xC0 == 0x80 {
//            lastMessageType = 0x80
//            segmentedData.append(rawResponse.dropFirst())
//        } else if rawResponse[0] & 0xC0 == 0xC0 {
//            lastMessageType = 0xC0
//            segmentedData.append(Data(rawResponse.dropFirst()))
//            //Copy data and send it to NetworkLayer
//            if let responseMsg = receivedData(incomingData: Data(rawResponse)) {
//                return (StatusMessageResponse(statusMessage: responseMsg))
//            }
//            segmentedData = Data()
//        } else {
//            if let responseMsg = receivedData(incomingData: Data(rawResponse)) {
//                return (StatusMessageResponse(statusMessage: responseMsg))
//            }
//        }
        
        return nil
    }
    
    func handleNotificationResponse(rawData: Data) -> BLEResponse? {
//        if rawResponse[0] & 0xC0 == 0x40 {
//        } else if rawResponse[0] & 0xC0 == 0x80 {
//        } else if rawResponse[0] & 0xC0 == 0xC0 {
//        } else {
//            if let responseMsg = receivedData(incomingData: Data(rawResponse)) {
//                return (StatusMessageResponse(statusMessage: responseMsg))
//            }
//        }
        
        return nil
    }
    
    func handleNotificationResponse(message: BLEResponse) {
//        if message is StatusMessageResponse {
//            let statusMsg = message as! StatusMessageResponse
//            if statusMsg.statusMessage is SimpleOnOffStatusMessage {
//                MeshNodeController.lightStateChangedMessage(statusMsg.statusMessage as! SimpleOnOffStatusMessage)
//            } else if statusMsg.statusMessage is SimpleLevelStatusMessage {
//                MeshNodeController.lightLevelChangedMessage(statusMsg.statusMessage as! SimpleLevelStatusMessage)
//            } else if statusMsg.statusMessage is HealthStatusMessage {
//                MeshNodeController.lightHealthStatusMessage(statusMsg.statusMessage as! HealthStatusMessage)
//            }
//        }
    }
}
