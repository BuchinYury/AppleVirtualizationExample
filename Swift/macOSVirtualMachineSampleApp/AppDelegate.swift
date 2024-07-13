/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app delegate that sets up and starts the virtual machine.
*/

import Cocoa
import Foundation
import Virtualization

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!

    @IBOutlet weak var virtualMachineView: VZVirtualMachineView!

    private var virtualMachineResponder: MacOSVirtualMachineDelegate?

    private var virtualMachine: VZVirtualMachine!

    // MARK: Create the Mac platform configuration.

#if arch(arm64)
    private func createMacPlaform() -> VZMacPlatformConfiguration {
        let macPlatform = VZMacPlatformConfiguration()

        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: auxiliaryStorageURL)
        macPlatform.auxiliaryStorage = auxiliaryStorage

        if !FileManager.default.fileExists(atPath: vmBundlePath) {
            fatalError("Missing Virtual Machine Bundle at \(vmBundlePath). Run InstallationTool first to create it.")
        }

        // Retrieve the hardware model and save this value to disk
        // during installation.
        guard let hardwareModelData = try? Data(contentsOf: hardwareModelURL) else {
            fatalError("Failed to retrieve hardware model data.")
        }

        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
            fatalError("Failed to create hardware model.")
        }

        if !hardwareModel.isSupported {
            fatalError("The hardware model isn't supported on the current host")
        }
        macPlatform.hardwareModel = hardwareModel

        // Retrieve the machine identifier and save this value to disk
        // during installation.
        guard let machineIdentifierData = try? Data(contentsOf: machineIdentifierURL) else {
            fatalError("Failed to retrieve machine identifier data.")
        }

        guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            fatalError("Failed to create machine identifier.")
        }
        macPlatform.machineIdentifier = machineIdentifier

        return macPlatform
    }

    // MARK: Create the virtual machine configuration and instantiate the virtual machine.

    private func createVirtualMachine() {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()

        virtualMachineConfiguration.platform = createMacPlaform()
        virtualMachineConfiguration.bootLoader = MacOSVirtualMachineConfigurationHelper.createBootLoader()
        virtualMachineConfiguration.cpuCount = MacOSVirtualMachineConfigurationHelper.computeCPUCount()
        virtualMachineConfiguration.memorySize = MacOSVirtualMachineConfigurationHelper.computeMemorySize()
        virtualMachineConfiguration.graphicsDevices = [MacOSVirtualMachineConfigurationHelper.createGraphicsDeviceConfiguration()]
        virtualMachineConfiguration.storageDevices = [MacOSVirtualMachineConfigurationHelper.createBlockDeviceConfiguration()]
        virtualMachineConfiguration.networkDevices = [MacOSVirtualMachineConfigurationHelper.createNetworkDeviceConfiguration()]
        virtualMachineConfiguration.pointingDevices = [MacOSVirtualMachineConfigurationHelper.createPointingDeviceConfiguration()]
        virtualMachineConfiguration.keyboards = [MacOSVirtualMachineConfigurationHelper.createKeyboardConfiguration()]
        virtualMachineConfiguration.consoleDevices = [MacOSVirtualMachineConfigurationHelper.createClipboardConsoleDeviceConfiguration()]
        
//        virtualMachineConfiguration.consoleDevices = [MacOSVirtualMachineConfigurationHelper.createConsoleDevicesConfiguration()]
//        virtualMachineConfiguration.serialPorts = [MacOSVirtualMachineConfigurationHelper.createSerialPortConfiguration()]
        virtualMachineConfiguration.socketDevices = [MacOSVirtualMachineConfigurationHelper.createSocketDeviceConfiguration()]

        try! virtualMachineConfiguration.validate()

        if #available(macOS 14.0, *) {
            try! virtualMachineConfiguration.validateSaveRestoreSupport()
        }

        virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
    }

    // MARK: Start or restore the virtual machine.

    func startVirtualMachine() {
        virtualMachine.start(completionHandler: { [weak self] (result) in
            if case let .failure(error) = result {
                fatalError("Virtual machine failed to start with \(error)")
            }
            
            guard let self,
                  let virtualMachine = self.virtualMachine,
                  let socketDevice = virtualMachine.socketDevices.first as? VZVirtioSocketDevice
            else { return }
            
            DispatchQueue.main.async {
                _ = socketDevice.listen(port: 8080, with: self)
            }
            
            print(">>> socketDevice is", socketDevice)
            self.connect(socketDevice: socketDevice, port: 8080)
        })
    }
    
    func connect(
        socketDevice: VZVirtioSocketDevice,
        port: UInt32
    ) {
        socketDevice.connect(toPort: port) { result in
            print(">>> VZVirtioSocketDevice.connect(toPort: port) result =", result)
            
            switch result {
            case let .success(connection):
                print(">>> connection", connection)
            case let .failure(error):
                print(">>> error", error)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.connect(socketDevice: socketDevice, port: port)
                }
            }
        }
    }

    func resumeVirtualMachine() {
        virtualMachine.resume(completionHandler: { (result) in
            if case let .failure(error) = result {
                fatalError("Virtual machine failed to resume with \(error)")
            }
        })
    }

    @available(macOS 14.0, *)
    func restoreVirtualMachine() {
        virtualMachine.restoreMachineStateFrom(url: saveFileURL, completionHandler: { [self] (error) in
            // Remove the saved file. Whether success or failure, the state no longer matches the VM's disk.
            let fileManager = FileManager.default
            try! fileManager.removeItem(at: saveFileURL)

            if error == nil {
                self.resumeVirtualMachine()
            } else {
                self.startVirtualMachine()
            }
        })
    }
#endif

    func applicationDidFinishLaunching(_ aNotification: Notification) {
#if arch(arm64)
        DispatchQueue.main.async { [self] in
            createVirtualMachine()
            virtualMachineResponder = MacOSVirtualMachineDelegate()
            virtualMachine.delegate = virtualMachineResponder
            virtualMachineView.virtualMachine = virtualMachine
            virtualMachineView.capturesSystemKeys = true

            if #available(macOS 14.0, *) {
                // Configure the app to automatically respond to changes in the display size.
                virtualMachineView.automaticallyReconfiguresDisplay = true
            }

            if #available(macOS 14.0, *) {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: saveFileURL.path) {
                    restoreVirtualMachine()
                } else {
                    startVirtualMachine()
                }
            } else {
                startVirtualMachine()
            }
        }
#endif
    }

    // MARK: Save the virtual machine when the app exits.

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
#if arch(arm64)
    @available(macOS 14.0, *)
    func saveVirtualMachine(completionHandler: @escaping () -> Void) {
        virtualMachine.saveMachineStateTo(url: saveFileURL, completionHandler: { (error) in
            guard error == nil else {
                fatalError("Virtual machine failed to save with \(error!)")
            }

            completionHandler()
        })
    }

    @available(macOS 14.0, *)
    func pauseAndSaveVirtualMachine(completionHandler: @escaping () -> Void) {
        virtualMachine.pause(completionHandler: { (result) in
            if case let .failure(error) = result {
                fatalError("Virtual machine failed to pause with \(error)")
            }

            self.saveVirtualMachine(completionHandler: completionHandler)
        })
    }
#endif

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
#if arch(arm64)
        if #available(macOS 14.0, *) {
            if virtualMachine.state == .running {
                pauseAndSaveVirtualMachine(completionHandler: {
                    sender.reply(toApplicationShouldTerminate: true)
                })
                
                return .terminateLater
            }
        }
#endif

        return .terminateNow
    }
}

extension AppDelegate: VZVirtioSocketListenerDelegate {
    
    func listener(
        _ listener: VZVirtioSocketListener,
        shouldAcceptNewConnection connection: VZVirtioSocketConnection,
        from socketDevice: VZVirtioSocketDevice
    ) -> Bool {
        print(">>> VZVirtioSocketListenerDelegate.listener connection =", connection)
        return true
    }
}
