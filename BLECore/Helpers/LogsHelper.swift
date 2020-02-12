//
//  LogsHelper.swift
//
//  Created by Mikhail Muravev on 11/01/2019.
//  Copyright © 2019 M-Technology. All rights reserved.
//

import Foundation

#if DEBUG
func dLog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    print("[\(NSURL(fileURLWithPath: filename).lastPathComponent.orNil):\(line)] \(function) - \(message)")
}
func dNSLog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    NSLog("[\(NSURL(fileURLWithPath: filename).lastPathComponent.orNil):\(line)] \(function) - %@", message)
}
#else
func dLog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    print("")
}
func dNSLog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    print("")
}
#endif

func pLog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    NSLog("[\(URL(fileURLWithPath: filename).lastPathComponent):\(line)] \(function) - %@", message)
}
