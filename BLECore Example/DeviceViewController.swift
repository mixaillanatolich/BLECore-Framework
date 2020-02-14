//
//  DeviceViewController.swift
//  BLECore
//
//  Created by Mixaill on 13.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import UIKit

class DeviceViewController: BaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    @IBAction func sendCmdButtonClicked(_ sender: Any) {
        let request = BLERequest(rawData: [("$0;".data(using: .utf8) ?? Data())], requestCharacteristic: "FFE1", responseCharacteristic: "FFE1")
        request.isWaitResponse = true
        request.isWriteWithResponse = true
        request.mode = .write
        request.retryCount = 2
        
        let command = BLECommand(with: request)
        command.responseCallback = { (status, response, error) in
            dLog("status: \(status)")
            dLog("response: \(response?.dataAsString().orNil)")
            dLog("error: \(error.orNil)")
        }

        BLEManager.currentDevice?.addCommandToQueue(command)
    }
    
    
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
