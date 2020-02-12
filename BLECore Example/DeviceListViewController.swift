//
//  DeviceListViewController.swift
//  BLECore
//
//  Created by Mixaill on 10.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import UIKit

class DeviceListViewController: UIViewController {

    fileprivate var queue = DispatchQueue(label: "com.m-technologies.thread", attributes: DispatchQueue.Attributes.concurrent)
    
    fileprivate var timeoutWorkItem: DispatchWorkItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func buttonClicked(_ sender: Any) {
        dNSLog("start")
        timeoutWorkItem?.cancel()
        timeoutWorkItem = DispatchWorkItem {
            dNSLog("work item run")
            guard let item = self.timeoutWorkItem, !item.isCancelled else {
                dNSLog("work item not exist or cancelled")
                return
            }
            self.connectionTimeout()
        }
        queue.asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem!)
    }
    @IBAction func button2Clicked(_ sender: Any) {
         dNSLog("cancel")
        timeoutWorkItem?.cancel()
    }
    
    func connectionTimeout() {
        dNSLog("connection timeout")
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
