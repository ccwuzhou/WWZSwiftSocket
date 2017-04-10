//
//  WWZSocketPong.swift
//  WWZSwiftSocket
//
//  Created by wwz on 2017/4/8.
//  Copyright © 2017年 tijio. All rights reserved.
//

import UIKit

open class WWZSocketPong: NSObject {
    
    public var timeout : TimeInterval = 10
    
    public var api_name : String
    
    private var timeoutHandle : (()->())?
    
    private var timer : Timer?
    
    public init(api_name: String, timeout: TimeInterval, timeoutHandle: (()->())?) {
        
        self.api_name = api_name
        
        self.timeout = timeout
        
        self.timeoutHandle = timeoutHandle
    }
    
    /// 恢复
    public func start() {
        
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: self.timeout, target: self, selector: #selector(WWZSocketPong.execTimer), userInfo: nil, repeats: true)
        }
    }
    
    @objc private func execTimer() {
        
        WWZTCPSocketRequest.shared.requestTimeout = 1
        
        WWZTCPSocketRequest.shared.request(api: self.api_name, parameters: [], success: { (_) in
            
            WWZTCPSocketRequest.shared.requestTimeout = 10
            
            print("socket not need to reconnect")
            
        }) { (error) in
            
            WWZTCPSocketRequest.shared.requestTimeout = 10
            
            self.timeoutHandle?()
        }
    }
    
    /// 暂停
    public func stop() {
        
        if timer != nil {
            
            timer?.invalidate()
            timer = nil
        }
    }
}

