//
//  SettingsView.swift
//  capturesingleentryswiftui-ios
//
//  Created by BS-272 on 9/11/21.
//

import SwiftUI
import SKTCapture

struct SettingsView: View,  CaptureHelperDevicePresenceDelegate, CaptureHelperDeviceManagerPresenceDelegate {
    
    @State var deviceManager: CaptureHelperDeviceManager?
    @State var softscan = false
    @State var nfcsupport = false
    @State var captureVersion = ""
    
    
    var body: some View {
        VStack {
            Toggle("SoftScan", isOn: $softscan)
                .onChange(of: softscan) { value in
                //perform your action here...
                    if(!softscan){
                        print("disabling SoftScan...")
                        CaptureHelper.sharedInstance.setSoftScanStatus(.disable, withCompletionHandler: { (result) in
                          print("disabling softScan returned \(result.rawValue)")
                        })
                    }
                    else{
                        print("enabling SoftScan...")
                        CaptureHelper.sharedInstance.setSoftScanStatus(.enable, withCompletionHandler: { (result) in
                            print("enabling softScan returned \(result.rawValue)")
                        })
                    }
            }
            Toggle("NFC Support", isOn: $nfcsupport)
                .onChange(of: nfcsupport) { value in
                //perform your action here...
                    let deviceManagers = CaptureHelper.sharedInstance.getDeviceManagers()
                    for d in deviceManagers {
                        deviceManager = d
                    }
                    if let dm = deviceManager {
                        if nfcsupport {
                            print("turn off the NFC support...")
                            dm.setFavoriteDevices("", withCompletionHandler: { (result) in
                                print("turning off NFC support returns \(result.rawValue)")
                            })
                        }
                        else {
                            print("turn on the NFC support...")
                            dm.setFavoriteDevices("*", withCompletionHandler: { (result) in
                                print("turning off NFC support returns \(result.rawValue)")
                            })
                        }
                    }
                    else {
                        nfcsupport = false
                    }
            }
            Text(captureVersion)
            Spacer()
        }
        .toggleStyle(.switch)
        .padding()
        .onAppear {
            
            CaptureHelper.sharedInstance.pushDelegate(self)
            // retrieve the current status of SoftScan
            let capture = CaptureHelper.sharedInstance

            capture.getSoftScanStatusWithCompletionHandler( {(result, softScanStatus) in
                print("getSoftScanStatusWithCompletionHandler received!")
                print("Result:", result.rawValue)
                if result == SKTCaptureErrors.E_NOERROR {
                    let status = softScanStatus
                    print("receive SoftScan status:",status ?? .disable)
                    if status == .enable {
                        self.softscan = true
                    } else {
                        self.softscan = false
                        if status == .notSupported {
                            capture.setSoftScanStatus(.supported, withCompletionHandler: { (result) in
                              print("setting softscan to supported returned \(result.rawValue)")
                            })
                        }
                    }
                }
            })
            
            // ask for the Capture version
            CaptureHelper.sharedInstance.getVersionWithCompletionHandler({ (result, version) in
                print("getCaptureVersion completion received!")
                print("Result:", result.rawValue)
                if result == SKTCaptureErrors.E_NOERROR {
                    let major = String(format:"%d",(version?.major)!)
                    let middle = String(format:"%d",(version?.middle)!)
                    let minor = String(format:"%d",(version?.minor)!)
                    let build = String(format:"%d",(version?.build)!)
                    print("receive Capture version: \(major).\(middle).\(minor).\(build)")
                    self.captureVersion = "Capture Version: \(major).\(middle).\(minor).\(build)"
                }
            })
            
            // check the NFC support
            if let dm = deviceManager {
                dm.getFavoriteDevicesWithCompletionHandler({ (result, favorites) in
                    print("getting the Device Manager favorites returns \(result.rawValue)")
                    if result == SKTCaptureErrors.E_NOERROR {
                        if let fav = favorites {
                            nfcsupport = !fav.isEmpty
                        }
                    }
                })
            }
        }
    }
    
    // MARK: - CaptureHelper Delegates
    /**
    * called each time a device connects to the host
    * @param result contains the result of the connection
    * @param newDevice contains the device information
    */
    func didNotifyArrivalForDevice(_ device: CaptureHelperDevice, withResult result: SKTResult) {
        print("Settings: Device Arrival")
    }
    
    /**
    * called each time a device disconnect from the host
    * @param deviceRemoved contains the device information
    */
    func didNotifyRemovalForDevice(_ device: CaptureHelperDevice, withResult result: SKTResult) {
        print("Settings: Device Removal")
    }
    
    func didNotifyArrivalForDeviceManager(_ device: CaptureHelperDeviceManager, withResult result: SKTResult) {
        print("Settings: Device Manager Arrival")
        deviceManager = device
        deviceManager?.getFavoriteDevicesWithCompletionHandler({ (result, favorites) in
            if result == SKTCaptureErrors.E_NOERROR {
                nfcsupport = !favorites!.isEmpty
            }
        })
    }
    
    func didNotifyRemovalForDeviceManager(_ device: CaptureHelperDeviceManager, withResult result: SKTResult) {
        print("Settings: Device Manager Removal")
        deviceManager = nil
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
