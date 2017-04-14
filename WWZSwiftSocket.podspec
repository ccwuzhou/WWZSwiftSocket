Pod::Spec.new do |s|
  s.name         = "WWZSwiftSocket"
  s.version      = "0.0.6"
  s.summary      = "A short description of WWZSwiftSocket."
  s.homepage     = "https://github.com/ccwuzhou/WWZSwiftSocket"
  s.license      = "MIT"
  s.author             = { "wwz" => "wwz@zgkjd.com" }
  s.platform     = :ios
  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/ccwuzhou/WWZSwiftSocket.git", :tag => "#{s.version}"}
  s.framework = 'Foundation'
  s.requires_arc = true
  s.source_files = "Source/*.swift"
  s.dependency "CocoaAsyncSocket"
  s.dependency "AFNetworking"
end
