//
//  BLEError.swift
//  BLECore
//
//  Created by Mixaill on 12.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import Foundation

public enum BLEError {
    case connection(type: Enums.ConnectionError)
    case communication(type: Enums.CommunicationError)
    case custom(errorDescription: String?)

    public class Enums { }
}

extension BLEError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .connection(let type): return type.localizedDescription
            case .communication(let type): return type.localizedDescription
            case .custom(let errorDescription): return errorDescription
        }
    }
}

// MARK: - Connection Errors

extension BLEError.Enums {
    public enum ConnectionError {
        case failToConnect
        case connectionTimeout
        case missedServices
        case missedCharacteristics
        case custom(errorCode: Int?, errorDescription: String?)
    }
}

extension BLEError.Enums.ConnectionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .failToConnect: return "Fail Connect To Device"
            case .connectionTimeout: return "Connect To Device Timeout"
            case .missedServices: return "Missed Services"
            case .missedCharacteristics: return "Missed Characteristics"
            case .custom(_, let errorDescription): return errorDescription
        }
    }

    public var errorCode: Int? {
        switch self {
            case .failToConnect: return 100
            case .connectionTimeout: return 101
            case .missedServices: return 102
            case .missedCharacteristics: return 103
            case .custom(let errorCode, _): return errorCode
        }
    }
}

// MARK: - Communication Errors

extension BLEError.Enums {
    public enum CommunicationError {
        case reseted
        case disconnected
        case timeout
        case updateCharacteristicValue(error: Error)
        case writeCharacteristicValue(error: Error)
        case custom(errorCode: Int?, errorDescription: String?)
    }
}

extension BLEError.Enums.CommunicationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .reseted: return "Reset connection"
            case .disconnected: return "Device disconnected"
            case .timeout: return "Send command timeout"
            case .updateCharacteristicValue(let error): return "Error update characteristic value \(error)"
            case .writeCharacteristicValue(let error): return "Error write characteristic value \(error)"
            case .custom(_, let errorDescription): return errorDescription
        }
    }
    
    public var errorCode: Int? {
        switch self {
            case .reseted: return 200
            case .disconnected: return 201
            case .timeout: return 202
            case .updateCharacteristicValue: return 203
            case .writeCharacteristicValue: return 204
            case .custom(let errorCode, _): return errorCode
        }
    }
}


//MARK: - Example of use
/*
let err: Error = AppError.network(type: .custom(errorCode: 400, errorDescription: "Bad request"))

switch err {
    case is AppError:
        switch err as! AppError {
        case .network(let type): print("Network ERROR: code \(type.errorCode), description: \(type.localizedDescription)")
        case .file(let type):
            switch type {
                case .read: print("FILE Reading ERROR")
                case .write: print("FILE Writing ERROR")
                case .custom: print("FILE ERROR")
            }
        case .custom: print("Custom ERROR")
    }
    default: print(err)
}
*/
