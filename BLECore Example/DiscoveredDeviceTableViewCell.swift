//
//  DiscoveredDeviceTableViewCell.swift
//  BLECore
//
//  Created by Mixaill on 12.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import UIKit

class DiscoveredDeviceTableViewCell: UITableViewCell {

     @IBOutlet weak var deviceName: UILabel!
     @IBOutlet weak var rssiLabel: UILabel!
     @IBOutlet weak var signalLevelIndicator1: UIView!
     @IBOutlet weak var signalLevelIndicator2: UIView!
     @IBOutlet weak var signalLevelIndicator3: UIView!
     @IBOutlet weak var signalLevelIndicator4: UIView!
     @IBOutlet weak var signalLevelIndicator5: UIView!
     
     override func awakeFromNib() {
         super.awakeFromNib()
     }
     
     override func setSelected(_ selected: Bool, animated: Bool) {
         super.setSelected(selected, animated: animated)
         
     }

     func resetCell() {
         rssiLabel.text = "RSSI: n/a"
         signalLevelIndicator5.backgroundColor=UIColor.lightGray
         signalLevelIndicator4.backgroundColor=UIColor.lightGray
         signalLevelIndicator3.backgroundColor=UIColor.lightGray
         signalLevelIndicator2.backgroundColor=UIColor.lightGray
         signalLevelIndicator1.backgroundColor=UIColor.lightGray
     }

}
