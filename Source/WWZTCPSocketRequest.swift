//
//  WWZTCPSocketRequest.swift
//  WWZSwift
//
//  Created by wwz on 17/3/21.
//  Copyright © 2017年 tijio. All rights reserved.
//

import UIKit

fileprivate struct WWZSocketRequestModel {
    
    var name : String
    var success : ((Any)->())?
    var failure : ((Error)->())?
}

open class WWZTCPSocketRequest: NSObject {
    
    // MARK: -公有属性
    /// api前缀
    public static let noti_prefix = "wwz"
    
    public var tcpSocket : WWZTCPSocketClient?
    
    /// 请求模版@"{\"app\":\"kjd\",\"co\":\"kjd\",\"api\":\"[api]\",\"data\":[param]}\n"
    public var api_model : String?
    /// 单例
    public static let shared : WWZTCPSocketRequest = WWZTCPSocketRequest()
    
    /// 请求超时时间
    public var requestTimeout : TimeInterval = 10.0
    
    // MARK: -私有属性
    fileprivate var mRequestModels = [WWZSocketRequestModel]()
    
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
                    
                    let noti = Notification(name: Notification.Name(noti_name), object: nil)
                    
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
        
        for (index, model) in self.mRequestModels.enumerated() {
            
            guard model.name == noti_name else { continue }
            
            if noti.object != nil {
                
                model.success?(noti.object)
                
            }else{
                
                model.failure?(NSError(domain: NSCocoaErrorDomain, code: -1, userInfo: ["error": "request error"]))
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
        
        guard let api_model = self.api_model else{
            return nil
        }
        
        return api_model.replacingOccurrences(of: "[api]", with: api).replacingOccurrences(of: "[param]", with: param)
    }
}
