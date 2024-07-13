/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The helper that creates various configuration objects exposed in the `VZVirtualMachineConfiguration`.
*/

import Foundation
import Virtualization

#if arch(arm64)

struct MacOSVirtualMachineConfigurationHelper {
    static func computeCPUCount() -> Int {
        let totalAvailableCPUs = ProcessInfo.processInfo.processorCount

        var virtualCPUCount = totalAvailableCPUs <= 1 ? 1 : totalAvailableCPUs - 1
        virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)

        return virtualCPUCount
    }

    static func computeMemorySize() -> UInt64 {
        // Set the amount of system memory to 4 GB; this is a baseline value
        // that you can change depending on your use case.
        var memorySize = (4 * 1024 * 1024 * 1024) as UInt64
        memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
        memorySize = min(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)

        return memorySize
    }

    static func createBootLoader() -> VZMacOSBootLoader {
        return VZMacOSBootLoader()
    }

    static func createGraphicsDeviceConfiguration() -> VZMacGraphicsDeviceConfiguration {
        let graphicsConfiguration = VZMacGraphicsDeviceConfiguration()
        graphicsConfiguration.displays = [
            // The system arbitrarily chooses the resolution of the display to be 1920 x 1200.
            VZMacGraphicsDisplayConfiguration(widthInPixels: 1920, heightInPixels: 1200, pixelsPerInch: 80)
        ]

        return graphicsConfiguration
    }

    static func createBlockDeviceConfiguration() -> VZVirtioBlockDeviceConfiguration {
        guard let diskImageAttachment = try? VZDiskImageStorageDeviceAttachment(url: diskImageURL, readOnly: false) else {
            fatalError("Failed to create Disk image.")
        }
        let disk = VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment)
        return disk
    }

    static func createNetworkDeviceConfiguration() -> VZVirtioNetworkDeviceConfiguration {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.macAddress = VZMACAddress.randomLocallyAdministered()

        let networkAttachment = VZNATNetworkDeviceAttachment()
        networkDevice.attachment = networkAttachment

        return networkDevice
    }

    static func createPointingDeviceConfiguration() -> VZPointingDeviceConfiguration {
        return VZMacTrackpadConfiguration()
    }

    static func createKeyboardConfiguration() -> VZKeyboardConfiguration {
        if #available(macOS 14.0, *) {
            return VZMacKeyboardConfiguration()
        } else {
            return VZUSBKeyboardConfiguration()
        }
    }
    
    static func createConsoleDevicesConfiguration() -> VZConsoleDeviceConfiguration {
        let configuration = VZVirtioConsoleDeviceConfiguration()
        return configuration
    }
    
    static func createSerialPortConfiguration() -> VZSerialPortConfiguration {
        let configuration = VZVirtioConsoleDeviceSerialPortConfiguration()
        configuration.attachment = VZFileHandleSerialPortAttachment(
            fileHandleForReading: nil,
            fileHandleForWriting: nil
        )
        return configuration
    }
    
    static func createSocketDeviceConfiguration() -> VZSocketDeviceConfiguration {
        let configuration = VZVirtioSocketDeviceConfiguration()
        return configuration
    }
    
    // TO-DO
    static func createClipboardConsoleDeviceConfiguration() -> VZConsoleDeviceConfiguration {
        let spiceClipboardAgent = VZSpiceAgentPortAttachment()
        spiceClipboardAgent.sharesClipboard = true
        let consolePort = VZVirtioConsolePortConfiguration()
        consolePort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
//        print(">>> VZSpiceAgentPortAttachment.spiceAgentPortName =", VZSpiceAgentPortAttachment.spiceAgentPortName)
        consolePort.attachment = spiceClipboardAgent
        consolePort.isConsole = false
        
        let configuration = VZVirtioConsoleDeviceConfiguration()
//        print(">>> configuration.ports.maximumPortCount =", configuration.ports.maximumPortCount)
//        print(">>> configuration.ports[0] =", configuration.ports[0] == nil)
        configuration.ports[0] = consolePort
//        print(">>> configuration.ports[0] =", configuration.ports[0] == nil)
        return configuration
    }
}

#endif
