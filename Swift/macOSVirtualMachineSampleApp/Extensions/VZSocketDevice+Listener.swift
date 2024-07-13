//
//  VZSocketDevice+Listener.swift
//  macOSVirtualMachineSampleApp-Swift
//
//  Created by Yuriy Buchin on 12.07.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import Virtualization

extension VZVirtioSocketDevice {
    
    func listen(
        port: UInt32,
        with delegate: VZVirtioSocketListenerDelegate
    ) -> VZVirtioSocketListener {
        
        let listener = VZVirtioSocketListener()
        listener.delegate = delegate
        
        self.setSocketListener(listener, forPort: port)
//        self.connect(toPort: port) { result in
//            print(">>> VZVirtioSocketDevice.connect(toPort: port) result =", result)
//        }
        
        return listener
    }
}
