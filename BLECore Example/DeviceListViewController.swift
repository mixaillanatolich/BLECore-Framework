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
                    if let cell = self.tableView.cellForRow(at: reloadCellPath) as? DiscoveredDeviceTableViewCell {
                        cell.updateDeviceRSSI(rssi: blePeripheral.rssi)
                    }
                    //self.tableView.reloadRows(at: [reloadCellPath], with: .automatic)
                }
            }
        }
        
        BLEManager.setupConnectStatusCallback { (connectStatus, peripheral, devType, error) in
            
            dLog("conn status: \(connectStatus)")
            dLog("error: \(error.orNil)")
            
            if connectStatus == .ready {
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "ShowDeviceControlScreen", sender: self)
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
            //UUID: 0000FFE0-0000-1000-8000-00805F9B34FB
            BLEManager.startDiscovery(serviceUUIDs: [CBUUID(string: "FFE0")])
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
        
        let device = discoveredDevices[Array(self.discoveredDevices.keys)[indexPath.row]]!
        
        cell.deviceName.text = device.peripheral.name ?? "Unknown"
        cell.updateDeviceRSSI(rssi: device.rssi)
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let device = discoveredDevices[Array(self.discoveredDevices.keys)[indexPath.row]]!
        
        if BLEManager.isDiscovering() {
            startScanButtonClicked(startScanButton!)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // service [CBUUID(string: "FFE0")]
            // characteristic [CBUUID(string: "FFE1")]
            BLEManager.connectToDevice(device.peripheral, deviceType: .expectedDevice, serviceIds: [CBUUID(string: "FFE0")], characteristicIds: [CBUUID(string: "FFE1")], timeout: 10.0)
        }
        
    }

}
