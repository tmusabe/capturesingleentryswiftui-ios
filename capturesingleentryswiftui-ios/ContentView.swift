//
//  ContentView.swift
//  capturesingleentryswiftui-ios
//
//  Created by BS-272 on 9/11/21.
//

import SwiftUI
import SKTCapture

struct ContentView: View, CaptureHelperDevicePresenceDelegate,
                    CaptureHelperDeviceManagerPresenceDelegate,
                    CaptureHelperDeviceDecodedDataDelegate,
                    CaptureHelperErrorDelegate,
                    CaptureHelperDevicePowerDelegate{
   
    @State var objects: [String] = []
    @State var captureHelper = CaptureHelper.sharedInstance
    
    var body: some View {
        NavigationView {
            List {
                ForEach(objects, id:\.self) { object in
                    NavigationLink(destination: DetailView()) {
                        Text(object)
                    }
                }
            }
        }
        .onAppear {
            let AppInfo = SKTAppInfo()
            AppInfo.appKey = "MC4CFQC72fo7vpcV/821koU3mmsEAzhmPwIVAN5muZlrU5cTAuvUVVK+ioHeVKEz"
            AppInfo.appID = "ios:com.nvisionmobile.nvisionmobile4"
            AppInfo.developerID = "a9781787-9562-4406-be7f-649994d77d8b"
            
            // there is a stack of delegates the last push is the
            // delegate active, when a new view requiring notifications from the
            // scanner, then push its delegate and pop its delegate when the
            // view is done
            captureHelper.pushDelegate(self)
            
            // to make all the delegates able to update the UI without the app
            // having to dispatch the UI update code, set the dispatchQueue
            // property to the DispatchQueue.main
            captureHelper.dispatchQueue = DispatchQueue.main

            // open Capture Helper only once in the application
            captureHelper.openWithAppInfo(AppInfo, withCompletionHandler: { (_ result: SKTResult) in
                print("Result of Capture initialization: \(result.rawValue)")
                // if you don't need host Acknowledgment, and use the
                // scanner acknowledgment, then these few lines can be
                // removed (from the #if to the #endif)
                #if HOST_ACKNOWLEDGMENT
                    captureHelper.setConfirmationMode(confirmationMode: .modeApp, withCompletionHandler: { (result) in
                        print("Data Confirmation Mode returns : \(result.rawValue)")
                    })
                // to remove the Host Acknowledgment if it was set before
                // put back to the default Scanner Acknowledgment also called Local Acknowledgment
                #else
                    self.captureHelper.setConfirmationMode(.modeDevice, withCompletionHandler: { (result) in
                        print("Data Confirmation Mode returns : \(result.rawValue)")
                    })
                #endif
            })

            // add SingleEntry item from the begining in the main list
            objects.insert("SingleEntry", at: 0)
        }
    }
    
    // MARK: - Helper functions
    func displayBatteryLevel(_ level: UInt?, fromDevice device: CaptureHelperDevice, withResult result: SKTResult) {
        if result != .E_NOERROR {
            print("error while getting the device battery level: \(result.rawValue)")
        }
        else{
            let battery = SKTHelper.getCurrentLevel(fromBatteryLevel: Int(level!))
            print("the device \((device.deviceInfo.name)! as String) has a battery level: \(String(describing: battery))%")
        }
    }
    
    // MARK: - CaptureHelperDevicePresenceDelegate
    
    func didNotifyArrivalForDevice(_ device: CaptureHelperDevice, withResult result: SKTResult) {
        print("Main view device arrival:\(String(describing: device.deviceInfo.name))")
        
        // These few lines are only for the Host Acknowledgment feature,
        // if your application does not use this feature they can be removed
        // from the #if to the #endif
        #if HOST_ACKNOWLEDGMENT
            device.getDataAcknowledgmentWithCompletionHandler({(result, dataAcknowledgment) in
                if result == .E_NOERROR {
                    var localAck = dataAcknowledgment
                    if localAck == SKTCaptureDeviceDataAcknowledgment.on {
                        localAck = SKTCaptureDeviceDataAcknowledgment.off
                        device.setDataAcknowledgment(localAck, withCompletionHandler : {(result, propertyResult) in
                            if result != .E_NOERROR {
                                print("Set Local Acknowledgment returns: \(result.rawValue)")
                            }
                        })
                    }
                }
            })
            
            device.getDecodeActionWithCompletionHandler(completion: {(result: SKTResult, decodeAction: SKTCaptureLocalDecodeAction?) in
                if result == .E_NOERROR {
                    if decodeAction != .none {
                        decodeAction = .none
                        device.setDecodeAction(decodeAction: decodeAction, withCompletionHandler:{(result: SKTResult) in
                            if result != .E_NOERROR {
                                print("Set Decode Action returs: \(result.rawValue)")
                            }
                        })
                    }
                }
            })
        #else // to remove the Host Acknowledgment if it was set before
            device.getDataAcknowledgmentWithCompletionHandler({(result: SKTResult, dataAcknowledgment: SKTCaptureDeviceDataAcknowledgment?) in
                if result == .E_NOERROR {
                    if var localAck = dataAcknowledgment {
                        if localAck == .off {
                            localAck = .on
                            device.setDataAcknowledgment(localAck, withCompletionHandler: {(result: SKTResult) in
                                if result != .E_NOERROR {
                                    print("Set Data Acknowledgment returns: \(result.rawValue)")
                                }
                            })
                        }
                    }
                }
            })
            
            device.getDecodeActionWithCompletionHandler({ (result: SKTResult, decodeAction: SKTCaptureLocalDecodeAction?)->Void in
                if result == .E_NOERROR {
                    if decodeAction == .none {
                        var action = SKTCaptureLocalDecodeAction()
                        action.insert(.beep)
                        action.insert(.flash)
                        action.insert(.rumble)
                        device.setDecodeAction(action, withCompletionHandler: { (result) in
                            if result != .E_NOERROR {
                                print("Set Decode Action returns: \(result.rawValue)")
                            }
                            
                        })
                    }
                }
            })
        #endif
        device.getNotificationsWithCompletionHandler { (result :SKTResult, notifications:SKTCaptureNotifications?) in
            if result == .E_NOERROR {
                var notif = notifications!
                if !notif.contains(SKTCaptureNotifications.batteryLevelChange) {
                    print("scanner not configured for battery level change notification, doing it now...")
                    notif.insert(SKTCaptureNotifications.batteryLevelChange)
                    device.setNotifications(notif, withCompletionHandler: {(result)->Void in
                        if result != .E_NOERROR {
                            print("error while setting the device notifications configuration \(result.rawValue)")
                        } else {
                            device.getBatteryLevelWithCompletionHandler({ (result, batteryLevel) in
                                self.displayBatteryLevel(batteryLevel, fromDevice: device, withResult: result)
                            })
                        }
                    })
                                            
                } else {
                    print("scanner already configured for battery level change notification")
                    device.getBatteryLevelWithCompletionHandler({ (result, batteryLevel)->Void in
                        self.displayBatteryLevel(batteryLevel, fromDevice: device, withResult: result)
                    })
                }
            } else {
                if result == .E_NOTSUPPORTED {
                    print("scanner \(String(describing: device.deviceInfo.name)) does not support reading for notifications configuration")
                } else {
                    print("scanner \(String(describing: device.deviceInfo.name)) return an error \(result) when reading for notifications configuration")
                }
            }
        }
    }

    func didNotifyRemovalForDevice(_ device: CaptureHelperDevice, withResult result: SKTResult) {
        print("Main view device removal:\(device.deviceInfo.name!)")
    }

    // MARK: - CaptureHelperDeviceManagerPresenceDelegate
    // THIS IS THE PLACE TO TURN ON THE BLE FEATURE SO THE NFC READER CAN
    // BE DISCOVERED AND CONNECT TO THIS APP
    func didNotifyArrivalForDeviceManager(_ device: CaptureHelperDeviceManager, withResult result: SKTResult) {
        print("device manager arrival notification")
        // this device property completion block might update UI
        // element, then we set its dispatchQueue here to this app
        // main thread
        device.dispatchQueue = DispatchQueue.main
        device.getFavoriteDevicesWithCompletionHandler { (result, favorites) in
            print("getting the favorite devices returned \(result.rawValue)")
            if result == .E_NOERROR {
                if let fav = favorites {
                    // if favorites is empty (meaning NFC reader auto-discovery is off)
                    // then set it to "*" to connect to any NFC reader in the vicinity
                    // To turn off the BLE auto reconnection, set the favorites to
                    // an empty string
                    if fav.isEmpty {
                        device.setFavoriteDevices("*", withCompletionHandler: { (result) in
                            print("setting new favorites returned \(result.rawValue)")
                        })
                    }
                }
            }
        }
    }

    func didNotifyRemovalForDeviceManager(_ device: CaptureHelperDeviceManager, withResult result: SKTResult) {
        print("device manager removal notifcation")
    }
    // MARK: - CaptureHelperDeviceDecodedDataDelegate
    
    // This delegate is called each time a decoded data is read from the scanner
    // It has a result field that should be checked before using the decoded
    // data.
    // It would be set to SKTCaptureErrors.E_CANCEL if the user taps on the
    // cancel button in the SoftScan View Finder
    func didReceiveDecodedData(_ decodedData: SKTCaptureDecodedData?, fromDevice device: CaptureHelperDevice, withResult result: SKTResult) {
        
        if result == .E_NOERROR {
            let rawData = decodedData?.decodedData
            let rawDataSize = rawData?.count
            print("Size: \(String(describing: rawDataSize))")
            print("data: \(String(describing: decodedData?.decodedData))")
            let string = decodedData?.stringFromDecodedData()!
            print("Decoded Data \(String(describing: string))")
            #if HOST_ACKNOWLEDGMENT
                device.setDataConfirmationWithLed(led: .green, withBeep: .good, withRumble: .good, withCompletionHandler: {(result) -> Void in
                    if result != SKTCaptureErrors.E_NOERROR {
                        print("Set Data Confirmation returns: \(result.rawValue)")
                    }
                })
            #endif
        }
    }

    // MARK: - CaptureHelperErrorDelegate
    
    func didReceiveError(_ error: SKTResult) {
        print("Receive a Capture error: \(error.rawValue)")
    }

    // MARK: - CaptureHelperDevicePowerDelegate
    
    func didChangePowerState(_ powerState: SKTCapturePowerState, forDevice device: CaptureHelperDevice) {
        print("Receive a didChangePowerState \(powerState)")
    }
    
    func didChangeBatteryLevel(_ batteryLevel: Int, forDevice device: CaptureHelperDevice) {
        print("Receive a didChangeBatteryLevel \(batteryLevel)")
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
