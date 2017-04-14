//
//  WWZTCPSocketRequest.swift
//  WWZSwift
//
//  Created by wwz on 17/3/21.
//  Copyright © 2017年 tijio. All rights reserved.
//

import UIKit

open class WWZSocketResult : NSObject {
    
    public var api: String?
    public var app: String?
    public var co: String?
    public var data: Any?
    public var retcode: String?
    public var retmsg: String?
    
    convenience public init(json: [String: Any]) {
        
        self.init()
        
        self.setValuesForKeys(json)
    }
    override open func setValue(_ value: Any?, forUndefinedKey key: String) {}
}

fileprivate struct WWZSocketRequestModel {
    
    var name : String
    var success : ((Any)->())?
    var failure : ((Error)->())?
}

open class WWZTCPSocketRequest: NSObject {
    
    // MARK: -公有属性
    /// api前缀
    public static let noti_prefix = "wwz"
    
    /// 单例
    public static let shared : WWZTCPSocketRequest = WWZTCPSocketRequest()
    
    /// 请求超时时间
    public var requestTimeout : TimeInterval = 10.0
    
    // MARK: -私有属性
    fileprivate var APP_PARAM : String?
    fileprivate var CO_PARAM : String?
    
    fileprivate var tcpSocket : WWZTCPSocketClient?

    fileprivate var mRequestModels = [WWZSocketRequestModel]()
    
    /// set socket parameters
    ///
    /// - Parameters:
    ///     - socket:  WWZTCPSocketClient
    /// - Returns: none
    public func setSocket(socket: WWZTCPSocketClient, app_param: String?, co_param: String?) {
        
        self.tcpSocket = socket
        self.APP_PARAM = app_param
        self.CO_PARAM = co_param
    }
    
    /// request
    public func request(api: String, parameters: Any, success: ((_ result: Any)->())?, failure: ((_ error: Error)->())?){
        
        guard let socket = self.tcpSocket else { return }
        
        self.request(socket: socket, api: api, parameters: parameters, success: success, failure: failure)
    }
    
    public func request(socket: WWZTCPSocketClient, api: String, parameters: Any, success: ((_ result: Any)->())?, failure: ((_ error: Error)->())?){
        
        guard let message = self.p_formatCmd(api: api, parameters: parameters) else { return }
        
        self.request(socket: socket, api: api, message: message, success: success, failure: failure)
    }
    public func request(api: String, message: String, success: ((_ result: Any)->())?, failure: ((_ error: Error)->())?){
        
        guard let socket = self.tcpSocket else { return }
        
        self.request(socket: socket, api: api, message: message, success: success, failure: failure)
    }
    public func request(socket: WWZTCPSocketClient, api: String, message: String, success: ((_ result: Any)->())?, failure: ((_ error: Error)->())?){
        
        guard let data = (message as NSString).replacingOccurrences(of: "'", with: "").data(using: .utf8) else { return }
        
        self.request(socket: socket, api: api, data: data, success: success, failure: failure)
    }
    /// socket request
    ///
    /// - Parameters:
    ///     - socket:  WWZTCPSocketClient
    ///     - api:  api name
    ///     - data:  Data
    ///     - success:  success call back
    ///     - failure:  failure call back
    /// - Returns: none
    public func request(socket: WWZTCPSocketClient, api: String, data: Data, success: ((_ result: Any)->())?, failure: ((_ error: Error)->())?){
        
        let noti_name = WWZTCPSocketRequest.noti_prefix + "_" + api
        
        guard success != nil || failure != nil else {
            // 发送请求
            socket.sendToServer(data: data)
            return
        }
        
        // 添加通知
        NotificationCenter.default.addObserver(self, selector: #selector(WWZTCPSocketRequest.p_getResultNoti), name: NSNotification.Name(noti_name), object: nil)
        
        // 发送请求
        socket.sendToServer(data: data)
        
        let model = WWZSocketRequestModel(name: noti_name, success: success, failure: failure)
    
        self.mRequestModels.append(model)
        // 超时处理
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() +  self.requestTimeout) {
            
            self.mRequestModels.forEach({ (model) in
                
                if model.name == noti_name && model.failure != nil {
                    
                    let socketResult = WWZSocketResult()
                    
                    socketResult.retcode = "-1"
                    socketResult.retmsg = "request time out"
                    
                    let noti = Notification(name: Notification.Name(noti_name), object: socketResult)
                    
                    self.p_getResultNoti(noti: noti)
                }
            })
        }
    }
}

extension WWZTCPSocketRequest {
    
    // 私有方法
    /// 收到通知
    @objc fileprivate func p_getResultNoti(noti: Notification) {
        
        let noti_name = noti.name.rawValue
        
        guard let socketModel = noti.object as? WWZSocketResult else { return }
        
        guard let retcodeString = socketModel.retcode, let retcode = Int(retcodeString) else { return }
        
        for (index, model) in self.mRequestModels.enumerated() {
            
            guard model.name == noti_name else { continue }
            
            if retcode != -1 {
                
                model.success?(socketModel.data)
                
            }else{
                
                model.failure?(NSError(domain: NSCocoaErrorDomain, code: retcode, userInfo: ["error": socketModel.retmsg ?? "unknown error"]))
            }
            // 执行完移除回调
            self.mRequestModels.remove(at: index)
            
            break
        }
        
        if self.p_canRemoveObserver(name: noti_name) {
            
            // 移除通知
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(noti_name), object: nil)
        }
    }
    
    fileprivate func p_canRemoveObserver(name: String) -> Bool {
        
        for model in self.mRequestModels {
            
            if model.name == name {
                return false
            }
        }
        return true
    }
    /// 格式化指令
    fileprivate func p_formatCmd(api: String, parameters: Any) -> String?{
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted) else { return nil}
        
        guard var param = String(data: jsonData, encoding: .utf8) else { return nil}
        
        param = param.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "  \"", with: "\"").replacingOccurrences(of: " : ", with: ":")
        
        var message = "{"
        
        if let app = self.APP_PARAM {
            message = message.appendingFormat("\"app\":\"%@\",", app)
        }
        if let co = self.CO_PARAM {
            
            message = message.appendingFormat("\"co\":\"%@\",", co)
        }
        
        return message.appendingFormat("\"api\":\"%@\",\"data\":%@}\n", api, param)
    }
}
