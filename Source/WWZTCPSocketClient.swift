//
//  WWZTCPSocketClient.swift
//  wwz_swift
//
//  Created by wwz on 17/2/28.
//  Copyright © 2017年 tijio. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

private let CONNECT_TIME_OUT : TimeInterval = 5
private let READ_TIME_OUT : TimeInterval = -1
private let WRITE_TIME_OUT : TimeInterval = -1
private let WRITE_TAG : Int = 1
private let READ_TAG : Int = 0

// MARK: -代理协议
public protocol WWZTCPSocketClientDelegate : NSObjectProtocol {
    
    /// 连接成功回调
    func socket(_ socket: WWZTCPSocketClient, didConnectToHost host: String, port: UInt16)
    
    /// 收到数据回调
    func socket(_ socket: WWZTCPSocketClient, didRead result: Any)
    
    /// 断开连接回调
    func socket(_ sock: WWZTCPSocketClient, didDisconnectWithError err: Error?)
}

// MARK: -tcp socket
open class WWZTCPSocketClient: NSObject {
    
    // MARK: -公开属性
    /// 代理
    public weak var delegate : WWZTCPSocketClientDelegate?
    
    /// 读取结束符
    public var endKeyString : String? {
        
        didSet {
            
            self.endKeyData = endKeyString?.data(using: .utf8)
        }
    }
    /// 读取结束符
    public var endKeyData : Data?
    
    // MARK: -懒加载属性
    fileprivate lazy var socket : GCDAsyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue(label: "WWZTCPSocketClient"))
    
    // MARK: -公有方法
    /// connect to server
    ///
    /// - Parameters:
    ///     - host:  server host
    ///     - onPort:  server port
    /// - Returns: none
    public func connect(host: String, onPort: UInt16) {
        
        self.disconnect()
        
        guard let host = self.p_convertedHost(host: host) else {
            print("host converted fail")
            return
        }
        
        if (try? self.socket.connect(toHost: host, onPort: onPort, withTimeout: CONNECT_TIME_OUT)) == nil {
            
            print("connect fail")
        }
    }
    
    /// disconnect server
    public func disconnect() {
        
        if self.socket.isConnected {
            
            print("disconnect socket")
            
            self.socket.disconnect()
        }
    }
    
    /// send message to server
    ///
    /// - Parameters:
    ///     - string:  message
    /// - Returns: none
    public func sendToServer(string: String?) {
        
        guard var message = string else {
            return
        }
        guard message.characters.count != 0 else {
            return
        }
        
        message = (message as NSString).replacingOccurrences(of: "'", with: "")
        
        self.sendToServer(data: message.data(using: .utf8))
    }
    /// send data to server
    ///
    /// - Parameters:
    ///     - data:  data
    /// - Returns: none
    public func sendToServer(data: Data?) {
        
        guard let data = data else {
            return
        }
        guard data.count != 0 else {
            return
        }
        
        self.socket.write(data, withTimeout: WRITE_TIME_OUT, tag: WRITE_TAG)
    }
}
// MARK: -delegate
extension WWZTCPSocketClient : GCDAsyncSocketDelegate {
    
    /// 连接成功
    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("+++connect to server success")
        
        DispatchQueue.main.async {
            
            self.delegate?.socket(self, didConnectToHost: host, port: port)
        }
        // 连接成功开始读数据
        self.p_continueToRead()
    }
    /// 写成功
    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        
        // 写成功后开始读数据
        self.p_continueToRead()
    }
    /// 收到数据
    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        
        self.p_handleReadData(data: data)
    }
    /// 断开连接
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        
        print("+++socket disconnect+++");
        
        DispatchQueue.main.async {
            
            self.delegate?.socket(self, didDisconnectWithError: err)
        }
    }
    
}
// MARK: -私有方法
extension WWZTCPSocketClient {
    
    // MARK: -私有方法
    /// 处理收到的数据
    fileprivate func p_handleReadData(data: Data) {
        
        guard data.count != 0 else {
            
            self.p_continueToRead()
            
            return
        }
        var readData = data
        
        // 去掉结束符
        if let endKeyData = self.endKeyData {
            
            if data.count <= endKeyData.count {
                self.p_continueToRead()
                
                return
            }
            
            readData = (readData as NSData).subdata(with: NSRange(location: 0, length: data.count-endKeyData.count))
        }
        
        // Data转String失败
        guard let resultString = String(data: readData, encoding: .utf8) else {
            
            
            DispatchQueue.main.async {
                
                self.delegate?.socket(self, didRead: readData)
            }
            
            self.p_continueToRead()
            
            return
        }
        // json解析失败
        guard let result = try? JSONSerialization.jsonObject(with: readData, options: .mutableContainers) else {
            
            DispatchQueue.main.async {
                
                self.delegate?.socket(self, didRead: resultString)
            }
            
            self.p_continueToRead()
            
            return;
        }
        
        DispatchQueue.main.async {
            
            self.p_postNotification(result: result)
            
            self.delegate?.socket(self, didRead: result)
        }
        
        // 读完当前数据后继续读数
        self.p_continueToRead()
    }
    /// 发送通知
    fileprivate func p_postNotification(result: Any){
        
        guard let jsonDict = result as? [String: Any] else { return }
        
        let resultModel = WWZSocketResult(json: jsonDict)
        
        guard let api = resultModel.api else { return }
        
        NotificationCenter.default.post(name: NSNotification.Name("\(WWZTCPSocketRequest.noti_prefix)_\(api)"), object: resultModel)
        
    }
    /// 读数据
    fileprivate func p_continueToRead() {
        
        if let endKeyData = self.endKeyData {
            
            self.socket.readData(to: endKeyData, withTimeout: READ_TIME_OUT, tag: READ_TAG)
        }else{
            
            self.socket.readData(withTimeout: READ_TIME_OUT, tag: READ_TAG)
        }
    }
    
    // MARK: -help
    /// ip转ipv4/6
    fileprivate func p_convertedHost(host: String) -> String?{
        
        let hosts = try? GCDAsyncSocket.lookupHost(host, port: 0)
        
        guard let addresses = hosts else {
            return nil;
        }
        
        var address4 : Data?
        var address6 : Data?
        
        for item in addresses {
            
            guard let address = item as? Data else {
                continue
            }
            
            if address4 == nil && GCDAsyncSocket.isIPv4Address(address) {
                
                address4 = address
            }else if address6 == nil && GCDAsyncSocket.isIPv6Address(address)  {
                address6 = address
            }
        }
        
        return address6 != nil ? GCDAsyncSocket.host(fromAddress: address6!) : GCDAsyncSocket.host(fromAddress: address4!)
    }
}
