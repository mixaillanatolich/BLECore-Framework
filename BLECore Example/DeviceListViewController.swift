//
//  DeviceListViewController.swift
//  BLECore
//
//  Created by Mixaill on 10.02.2020.
//  Copyright © 2020 M-Technologies. All rights reserved.
//

import UIKit
import CoreBluetooth

class DeviceListViewController: BaseViewController {

    @IBOutlet weak var startScanButton: UIButton!
    @IBOutlet weak var tableView: UITableView!

    var discoveredDevices = [String: BLEPeripheral]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        BLEManager.setupDiscoveryDeviceCallback { (isNew, blePeripheral) in

            DispatchQueue.main.async {
                if isNew {
                    let addCellPath = IndexPath(item: Int(self.discoveredDevices.count), section: 0)
                    self.discoveredDevices[blePeripheral.uuid()] = blePeripheral
                    self.tableView.insertRows(at: [addCellPath], with: .automatic)
                } else {
                    self.discoveredDevices[blePeripheral.uuid()] = blePeripheral
                    let index = Array(self.discoveredDevices.keys).firstIndex(of: blePeripheral.uuid())
                    
                    let reloadCellPath = IndexPath(item: index!, section: 0)
                    self.tableView.reloadRows(at: [reloadCellPath], with: .automatic)
                }
            }
        }
    }
    
    @IBAction func startScanButtonClicked(_ sender: Any) {
        
        guard BLEManager.bluetoothEnabled() else {
            showAlert(withTitle: "Bluethooth Error", andMessage: BLEManager.alertMsgForCurrentBTState() ?? "Unknown error")
            return
        }
        
        if BLEManager.isDiscovering() {
            BLEManager.stopDiscovery()
            startScanButton.setTitle("Start Scan", for: .normal)
        } else {
            discoveredDevices = [String: BLEPeripheral]()
            tableView.reloadData()
            BLEManager.startDiscovery(serviceUUIDs: [CBUUID(string: "1827"), CBUUID(string: "1828")])
            startScanButton.setTitle("Stop Scan", for: .normal)
        }
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension DeviceListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:DiscoveredDeviceTableViewCell = self.tableView.dequeueReusableCell(withIdentifier: "DiscoveredPeripheralCell")! as! DiscoveredDeviceTableViewCell
        cell.resetCell()
        
        let device = discoveredDevices[Array(self.discoveredDevices.keys)[indexPath.row]]!
        
        cell.deviceName.text = device.peripheral.name ?? "Unknown"
        let peripheralRSSI = device.rssi
        cell.rssiLabel.text = "RSSI: \(peripheralRSSI)"
        
        if (peripheralRSSI.intValue > -55) {
            cell.signalLevelIndicator5.backgroundColor=UIColor.systemOrange
        }
        if (peripheralRSSI.intValue > -65) {
            cell.signalLevelIndicator4.backgroundColor=UIColor.systemOrange
        }
        if (peripheralRSSI.intValue > -75) {
            cell.signalLevelIndicator3.backgroundColor=UIColor.systemOrange
        }
        if (peripheralRSSI.intValue > -85) {
            cell.signalLevelIndicator2.backgroundColor=UIColor.systemOrange
        }
        if (peripheralRSSI.intValue > -95) {
            cell.signalLevelIndicator1.backgroundColor=UIColor.systemOrange
        }
        
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = discoveredDevices[Array(self.discoveredDevices.keys)[indexPath.row]]!
        
    }

}
