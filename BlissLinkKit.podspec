Pod::Spec.new do |s|
  s.name             = 'BlissLinkKit'
  s.version          = '1.0.4'
  s.summary          = 'BlissLink shared components with RevenueCat, AppsFlyer, Moya integration.'
  s.description      = <<-DESC
    BlissLinkKit provides shared base components including:
    - BlissLinkBaseDefaultViewController: splash + WebView flow
    - BlissLinkShare: IDFA, push, RevenueCat payments, Moya requests
    - BlissLinkExtension: common String/UIWindow/Dictionary extensions
  DESC
  s.homepage         = 'https://github.com/AppleCodeObj/BlissLinkKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'AppleCodeObj' => '444693592@qq.com' }
  s.source           = { :git => 'https://github.com/AppleCodeObj/BlissLinkKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '14.0'
  s.swift_version = '5.0'
  s.static_framework = true

  s.source_files = 'BlissLinkKit/Classes/**/*'

  s.dependency 'RevenueCat'
  s.dependency 'AppsFlyerFramework'
  s.dependency 'Moya'
  s.dependency 'Alamofire'
  s.dependency 'SVProgressHUD'
end