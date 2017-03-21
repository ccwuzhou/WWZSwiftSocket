//
//  WWZNetworkTool.swift
//  webo_swift
//
//  Created by wwz on 17/2/27.
//  Copyright © 2017年 tijio. All rights reserved.
//

import UIKit
import AFNetworking

public enum WWZRequestType: String {
    case GET = "GET"
    case POST = "POST"
}

open class WWZNetworkTool: AFHTTPSessionManager {

    public static let shareInstance : WWZNetworkTool = {
    
        let tools = WWZNetworkTool()
        tools.responseSerializer.acceptableContentTypes?.insert("text/html")
        tools.responseSerializer.acceptableContentTypes?.insert("text/plain")
        return tools
    }()
    
    // MARK: -请求方法
    public func request(_ methodType: WWZRequestType, urlString: String, parameters: [String: Any]?, success: ((_ result: Any?)->())?, failure: ((_ error: Error?)->())?) {
        
        let successCallBack = { (task: URLSessionDataTask, result: Any?) -> Void in

            success?(result)
        }
        let failureCallBack = { (task: URLSessionDataTask?, error: Error)  -> Void in
            
            failure?(error)
        }
        
        if methodType == .GET {
        
            self.get(urlString, parameters: parameters, progress: nil, success: successCallBack, failure: failureCallBack)
            
        }else{
        
            self.post(urlString, parameters: parameters, progress: nil, success: successCallBack, failure: failureCallBack)
        }
    }
    
    // MARK: -监听网络状态
    public class func wwz_networkReachability(notReachable: (()->())?, reachable: (()->())?) {
        
        AFNetworkReachabilityManager.shared().setReachabilityStatusChange { (status) in
            
            switch status {
                
            case .unknown, .notReachable:
                print("没有网络")
                if let notReachable = notReachable {
                    
                    notReachable()
                }
            case .reachableViaWWAN, .reachableViaWiFi:
                print("有网络")
                
                if let reachable = reachable {
                    
                    reachable()
                }
            }
        }
        
        AFNetworkReachabilityManager.shared().startMonitoring()
    }
}
