//
//  WWZUDPSocket.swift
//  wwz_swift
//
//  Created by wwz on 17/3/4.
//  Copyright © 2017年 tijio. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

public protocol WWZUDPSocketDelegate : NSObjectProtocol {
    
    func udpSocket(udpSocket: WWZUDPSocket, didReceiveData: Data, fromHost: String)
}

open class WWZUDPSocket: NSObject {

    private lazy var udpSocket : GCDAsyncUdpSocket = {
    
        let socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        socket.setIPv6Enabled(true)
        
        return socket
    }()
    
    public var delegate : WWZUDPSocketDelegate?
    
    // 开始监听
    public func startListen(port: UInt16) {
        
        try? self.udpSocket.bind(toPort: port)
        
        try? self.udpSocket.enableBroadcast(true)
        
        try? self.udpSocket.beginReceiving()
    }
    
    
    // 广播数据
    public func broadCastMessage(message: String, toPort: UInt16) {
    
        self.send(message: message, toHost: "255.255.255.255", port: toPort)
    }
    
    // 发送数据
    public func send(message: String, toHost host: String, port: UInt16){
    
        guard let data = message.data(using: .utf8) else {return}
        
        self.send(data: data, toHost: host, port: port)
    }
    
    // 发送数据
    public func send(data: Data, toHost host: String, port: UInt16) {
    
        self.udpSocket.send(data, toHost: host, port: port, withTimeout: -1, tag: 0)
    }
    
    public func close() {
    
        self.udpSocket.close()
    }
}

extension WWZUDPSocket : GCDAsyncUdpSocketDelegate {

    public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        
        guard let host = GCDAsyncUdpSocket.host(fromAddress: address) else { return }
        
        if let delegate = self.delegate {
            
            delegate.udpSocket(udpSocket: self, didReceiveData: data, fromHost: host)
        }
    }
}
