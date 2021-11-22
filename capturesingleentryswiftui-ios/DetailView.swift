//
//  DetailView.swift
//  capturesingleentryswiftui-ios
//
//  Created by BS-272 on 9/11/21.
//

import SwiftUI
import SKTCapture

struct DetailView: View, CaptureHelperDevicePresenceDelegate,CaptureHelperDeviceDecodedDataDelegate {
 
    let noScannerConnected = "No scanner connected"
    @State var connectionStatus: String = ""
    @State var decodeData: String = ""
    @State var scanners : [String] = []  // keep a list of scanners to display in the status
    @State var softScanner : CaptureHelperDevice?  // keep a reference on the SoftScan Scanner
    @State var lastDeviceConnected : CaptureHelperDevice?
    @State var captureHelper = CaptureHelper.sharedInstance
    
    @State var activeSettings = false
    @State var showSoftScanOverlay = false
    @State var showSoftScanTrigger = false
    @State var showAlert = false
    @State var errorTxt = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text("Status:")
                Spacer()
            }
            .padding()
            HStack(alignment: .top) {
                Text(connectionStatus)
                Spacer()
            }
            .padding()
            HStack(alignment: .top) {
                TextField("", text:$decodeData)
                    .border(Color.secondary)
                Spacer()
            }
            .padding()
            HStack(alignment: .top) {
                Spacer()
                NavigationLink(destination: SettingsView(),isActive: $activeSettings) {
                    Button(action: {
                        if let scanner = softScanner as CaptureHelperDevice? {
                            showSoftScanOverlay = true
                            scanner.setTrigger(.start, withCompletionHandler: {(result) in
                                self.displayAlertForResult(result, forOperation: "SetTrigger")
                                if result != .E_NOERROR {
                                    self.showSoftScanOverlay = false
                                }
                            })
                        }
                        else if let device = lastDeviceConnected {
                            device.setTrigger(.start, withCompletionHandler: { (result) in
                                print("triggering the device returns: \(result.rawValue)")
                            })
                        }
                    }) {
                        Text("Settings")
                    }
                }
                Spacer()
            }
            .padding()
            if showSoftScanTrigger {
                HStack(alignment: .top) {
                  Spacer()
                  Button(action: {
                      if let scanner = softScanner as CaptureHelperDevice? {
                          showSoftScanOverlay = true
                          scanner.setTrigger(.start, withCompletionHandler: {(result) in
                              self.displayAlertForResult(result, forOperation: "SetTrigger")
                              if result != .E_NOERROR {
                                  self.showSoftScanOverlay = false
                              }
                          })
                      }
                      else if let device = lastDeviceConnected {
                          device.setTrigger(.start, withCompletionHandler: { (result) in
                              print("triggering the device returns: \(result.rawValue)")
                          })
                      }
                  }) {
                    Text("Soft Scanner")
                  }
                  Spacer()
                }
                .padding()
            }
            Spacer()
        }
        .padding()
        .onAppear {
            if showSoftScanOverlay == false {
                // since we use CaptureHelper in shared mode, we push this
                // view controller delegate to the CaptureHelper delegates stack
                CaptureHelper.sharedInstance.pushDelegate(self)
            }
            showSoftScanOverlay = false
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Capture Error"), message: Text(errorTxt), dismissButton: .default(Text("Dismiss")))
        }
        .onDisappear {
            // if we are showing the SoftScan Overlay view we don't
            // want to remove our delegate from the CaptureHelper delegates stack
            if showSoftScanOverlay == false {
                // remove all the scanner names from the list
                // because in CaptureHelper shared mode we will receive again
                // the deviceArrival for each connected scanner once this view
                // becomes active again
                scanners = []
                showSoftScanTrigger = false;
                CaptureHelper.sharedInstance.popDelegate(self)
            }
        }
    }
    // MARK: - Utility functions
    func displayScanners(){
            // the main dispatch queue is required to update the UI
            // or the delegateDispatchQueue CaptureHelper property
            // can be set instead
//            DispatchQueue.main.async() {
                connectionStatus = ""
                for scanner in self.scanners {
                    connectionStatus = connectionStatus + (scanner as String) + "\n"
                }
                if(self.scanners.count == 0){
                    connectionStatus = self.noScannerConnected
                }
//            }
    
    }

    func displayAlertForResult(_ result: SKTResult, forOperation operation: String){
        if result != .E_NOERROR {
            errorTxt = "Error \(result.rawValue) while doing a \(operation)"
            showAlert = true
        }
    }
    
    
    // MARK: - CaptureHelperDeviceDecodedDataDelegate

    func didReceiveDecodedData(_ decodedData: SKTCaptureDecodedData?, fromDevice device: CaptureHelperDevice, withResult result:SKTResult) {
        print("didReceiveDecodedData in the detail view with result: \(result.rawValue)")
        if result == .E_NOERROR {
            if let rawData = decodedData!.decodedData {
                let rawDataSize = rawData.count
                print("Size: \(rawDataSize)")
                print("data: \(rawData)")
                let str = decodedData!.stringFromDecodedData()
                print("Decoded Data \(String(describing: str))")
                    self.decodeData = str ?? ""
                // this code can be removed if the application is not interested by
                // the host Acknowledgment for the decoded data
                #if HOST_ACKNOWLEDGMENT
                    device.setDataConfirmationWithLed(SKTCaptureDataConfirmationLed.green, withBeep:SKTCaptureDataConfirmationBeep.good, withRumble: SKTCaptureDataConfirmationRumble.good, withCompletionHandler: {(result) in
                        if result != .E_NOERROR {
                            print("error trying to confirm the decoded data: \(result.rawValue)")
                        }
                    })
                #endif
            }
        }
    }

    // MARK: - CaptureHelperDevicePresenceDelegate

    // since we use CaptureHelper in shared mode, we receive a device Arrival
    // each time this view becomes active and there is a scanner connected
    func didNotifyArrivalForDevice(_ device: CaptureHelperDevice, withResult result:SKTResult) {
        print("didNotifyArrivalForDevice in the detail view")
        let name = device.deviceInfo.name
        if(name?.caseInsensitiveCompare("SoftScanner") == ComparisonResult.orderedSame){
            showSoftScanTrigger = true;
            softScanner = device
            
            // set the Overlay View context to give a reference to this controller
            if let scanner = softScanner {
                let context : [String:Any] = [SKTCaptureSoftScanContext : self]
                
                scanner.setSoftScanOverlayViewParameter(context, withCompletionHandler: { (result) in
                    self.displayAlertForResult(result, forOperation: "SetOverlayView")
                })
            }
        }
        else {
            lastDeviceConnected = device
            showSoftScanTrigger = true;
        }
        scanners.append(device.deviceInfo.name!)
        displayScanners()
    }

    func didNotifyRemovalForDevice(_ device: CaptureHelperDevice, withResult result: SKTResult) {
        print("didNotifyRemovalForDevice in the detail view")
        var newScanners : [String] = []
        for scanner in scanners{
            if(scanner as String != device.deviceInfo.name){
                newScanners.append(scanner as String)
            }
        }
        // if the scanner that is removed is SoftScan then
        // we nil its reference
        if softScanner != nil {
            if softScanner == device {
                softScanner = nil
            }
        }
        scanners = newScanners
        displayScanners()
    }
}

struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        DetailView()
    }
}
