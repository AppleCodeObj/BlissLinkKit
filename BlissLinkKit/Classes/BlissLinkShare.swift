
import UIKit
import AppsFlyerLib
import AppTrackingTransparency
import AdSupport
import UserNotifications
import AVFoundation
import Photos
import Moya
import WebKit
import StoreKit
import RevenueCat
import AuthenticationServices
import Alamofire
class BlissLinkShare: NSObject {
    static let shared = BlissLinkShare()
    var blissLinkTrackingPermission : Int? = nil
    var blissLinkIdfaPermission : String = ""
    private  override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(blissLinkhandleScreenRecordingChange), name: UIScreen.capturedDidChangeNotification, object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    var blissLinkTargetView =  UIView()
    var blissLinkShieldOverlay = UIView()
    func blissLinkProtectView(_ controllerView: UIView) {
        self.blissLinkTargetView = controllerView
        self.blissLinkShieldOverlay = UIView(frame: controllerView.bounds)
        self.blissLinkShieldOverlay.backgroundColor = .black
        self.blissLinkShieldOverlay.isHidden = true
        self.blissLinkShieldOverlay.isUserInteractionEnabled = false
        self.blissLinkShieldOverlay.alpha = 1.0
        controllerView.addSubview(self.blissLinkShieldOverlay)
        blissLinkhandleScreenRecordingChange()
    }
    @objc private func      blissLinkhandleScreenRecordingChange() {
        blissLinkShieldOverlay.isHidden = !UIScreen.main.isCaptured
    }
    func blissLinkRegisterPushAndTrackIDFA() {
        NotificationCenter.default.addObserver(self, selector: #selector(blissLinkRegisterTrack), name: .blissLinkAppDidBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(blissLinkRegisterApns), name: .blissLinkAppDidBecomeActiveNotification, object: nil)
    }
    
    @objc  func blissLinkRegisterTrack() {
        AppsFlyerLib.shared().appsFlyerDevKey = BlissLinkConfig.shared.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = BlissLinkConfig.shared.appleAppID
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        self.blissLinkTrackingPermission = 1
                        self.blissLinkIdfaPermission = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                    case .denied, .restricted, .notDetermined:
                        self.blissLinkTrackingPermission = 0
                        self.blissLinkIdfaPermission = ""
                    @unknown default:
                        self.blissLinkTrackingPermission = 0
                        self.blissLinkIdfaPermission = ""
                    }
                }
            }
        } else {
            if ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
                self.blissLinkTrackingPermission = 1
                self.blissLinkIdfaPermission = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            } else {
                self.blissLinkTrackingPermission = 0
                self.blissLinkIdfaPermission = ""
            }
        }
        AppsFlyerLib.shared().start()
    }
    @objc  func blissLinkRegisterApns() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                
            }
        }
    }
    
    func blissLinkUpploadBadge(){
        UIApplication.shared.applicationIconBadgeNumber = Int.blissLinkBadgeNumber()
    }
    func blissLinkOpenDefaultViewController(){
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            BlissLinkConfig.shared.openDefaultViewControllerHandler?()
        }
    }
    func blissLinkUserContentController(webview:WKWebView,messaage:WKScriptMessage){
        guard let blissLinkBody = messaage.body as? [String: Any] else { return }
        let udValues = blissLinkBody.filter { $0.key.hasSuffix("_ud") }
        let taValues = blissLinkBody.filter { $0.key.hasSuffix("_ta") }
        guard let uuid = udValues.first?.value as? String,
              let dataDict = taValues.first?.value as? [String: Any] else {
            return
        }
        if messaage.name == "a" {
            blissLinkHandleOpenNativeModule(webview: webview, data: dataDict,uuid: uuid)
        }
    }
    func    blissLinkHandleOpenNativeModule(webview:WKWebView,data: [String: Any], uuid: String){
        let blissLinkCallback = data.first(where: { $0.key.hasSuffix("_cb") })?.value as? String ?? ""
        let blissLinkType = data.first(where: { $0.key.hasSuffix("_pe") })?.value as? String ?? ""
        let blissLinkTypeStr = String(blissLinkType.suffix(2))
        if blissLinkTypeStr == "gd"{
            blissLinkHandleGoods(webview: webview, data: data, uuid: uuid, callback: blissLinkCallback)
        }else if blissLinkTypeStr == "py"{
            blissLinkhandlePayment(webview:webview, data: data, uuid: uuid, callback: blissLinkCallback)
        }else if blissLinkTypeStr == "sr"{
            blissLinkHandleStore()
        }
    }
    
    
    func   blissLinkHandleGoods(webview:WKWebView,data: [String: Any],uuid: String,callback:String) {
        let blissLinkIds = data.first(where: { $0.key.hasSuffix("_is") })?.value as? [String] ?? []
        let UU = data.first(where: { $0.key.hasSuffix("_uu") })?.value as? String ?? ""
        
        blissLinkRevenuecatKey(BlissLinkConfig.shared.revenueCatKey, UU)
        blissLinkFetchProducts(blissLinkIds) { priceDict in
            var blissLinkDic: [String: Any] = [:]
            blissLinkDic[String.blissLinkRandom() + "ud"] = uuid
            blissLinkDic[String.blissLinkRandom() + "gd"] = priceDict
            if priceDict.count > 0 {
                DispatchQueue.main.async {
                    let js = String(format: "window.%@('%@',%@)",String.blissLinkTypeRandomStr(),callback,String.blissLinkJsonString(from:blissLinkDic) ?? "")
                    webview.evaluateJavaScript(js) { value, error in
                    }
                }
                
               
            }
        }
    }
  
    func     blissLinkhandlePayment(webview:WKWebView,data: [String: Any], uuid:String, callback: String ) {
        let blissLinkProductID = data.first(where: { $0.key.hasSuffix("_pi") })?.value as? String ?? ""
        let blissLinkOrderID = data.first(where: { $0.key.hasSuffix("_no") })?.value as? String ?? ""
        blissLinkStartPay(identifier: blissLinkProductID, orderId: blissLinkOrderID) { userId, status, orderId in
            var blissLinkDic: [String: Any] = [:]
            blissLinkDic[String.blissLinkRandom() + "ru"] = userId
            blissLinkDic[String.blissLinkRandom() + "ud"] = uuid
            blissLinkDic[String.blissLinkRandom() + "us"] = status
            blissLinkDic[String.blissLinkRandom() + "no"] = orderId  
            let js = String(format: "window.%@('%@',%@)",String.blissLinkTypeRandomStr(),callback,String.blissLinkJsonString(from:blissLinkDic) ?? "")
            webview.evaluateJavaScript(js) { value, error in
            }
          
        }
    }
    func    blissLinkHandleStore(){
        if let blissLinkScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            if #available(iOS 14.0, *) {
                SKStoreReviewController.requestReview(in: blissLinkScene)
            }
        }
    }
    func blissLinkRevenuecatKey(_ key:String,_ userID:String){
        if(!userID.blissLinkIsBlank){
            Purchases.configure(withAPIKey: key, appUserID: userID)
        }
    }
    func    blissLinkStartPay(identifier: String,
                                   orderId: String?,
                                   callback: @escaping (_ userId: String, _ status: Int, _ orderId: String) -> Void) {
        
        let blissLinkOrderId = orderId ?? ""
        
        Purchases.shared.getOfferings { (offerings, error) in
            if error != nil {
                callback( Purchases.shared.appUserID, 0,blissLinkOrderId)
                return
            }
            
            guard let offerings = offerings else {
                callback(Purchases.shared.appUserID, 0, blissLinkOrderId)
                return
            }
            if !blissLinkOrderId.isEmpty {
                do {
                    try Purchases.shared.attribution.setAttributes(["order_no": blissLinkOrderId])
                } catch {
                    print("Failed to set order_no attribute: \(error)")
                }
            }
            var found = false
            for (_, offering) in offerings.all {
                if offering.identifier == identifier {
                    found = true
                    let availablePackages = offering.availablePackages
                    self.blissLinkPurchasePackagesSequentially(packages: availablePackages,
                                                      orderId: blissLinkOrderId,
                                                      callback: callback,
                                                      currentIndex: 0)
                    return
                }
                
                if found { break }
            }
            if !found {
                callback(Purchases.shared.appUserID, 0, blissLinkOrderId)
            }
        }
        
    }
    private func  blissLinkPurchasePackage(_ package: Package,
                                 orderId: String,
                                 callback: @escaping (_ userId: String, _ status: Int, _ orderId: String) -> Void) {
        
        Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
            var blissLinkStatus = 1
            if userCancelled {
                blissLinkStatus = 2
            } else if error != nil {
                blissLinkStatus = 0
            }
            DispatchQueue.main.async {
                callback(Purchases.shared.appUserID, blissLinkStatus, orderId)
            }
        }
    }
    private func blissLinkPurchasePackagesSequentially(packages: [Package],
                                              orderId: String,
                                              callback: @escaping (_ userId: String, _ status: Int, _ orderId: String) -> Void,
                                              currentIndex: Int) {
        
        guard currentIndex < packages.count else {
            return
        }
        
        let blissLinkCurrentPackage = packages[currentIndex]
        blissLinkPurchasePackage(blissLinkCurrentPackage, orderId: orderId) { userId, status, orderId in
            callback(userId, status, orderId)
            
            if currentIndex + 1 >= packages.count {
                
                return
            }
            
            self.blissLinkPurchasePackagesSequentially(packages: packages,
                                              orderId: orderId,
                                              callback: callback,
                                              currentIndex: currentIndex + 1)
        }
        
    }

    func        blissLinkFetchProducts(_ productIDArray: [String], completion: @escaping ([[String: Any]]) -> Void) {
        let blissLinkRequest = SKProductsRequest(productIdentifiers: Set(productIDArray))
        let blissLinkDelegate = blissLinkProductRequestDelegate(completion: completion)
        blissLinkRequest.delegate = blissLinkDelegate
        objc_setAssociatedObject(blissLinkRequest, "delegate", blissLinkDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        blissLinkRequest.start()
    }
    
    
    let blissLinkGetProvider = MoyaProvider<BlissLinkGetAPIService>()
    func blissLinkGetRequest(successBlock: @escaping (_ isEnd: Bool) -> Void) {
        blissLinkGetProvider.request(.blissLinkGetEncodedUrl) { result in
            switch result {
            case .success(let response):
                guard let blissLinkRealData = response.data as? Data else { return }
                do {
                    let blissLinkJson = try JSONSerialization.jsonObject(with: blissLinkRealData) as? [String: Any] ?? [:]
                    let blissLinkCodeKey = "code"
                    let blissLinkDataKey = "data"
                    guard let code = blissLinkJson[blissLinkCodeKey],
                          let dataDict = blissLinkJson[blissLinkDataKey] as? [String: Any] else {
                        return
                    }
                    if String(format: "%@", code as! CVarArg) == "1003"{
                        let blissLinkLastKey = dataDict.keys.reversed().first as? String ?? ""
                        let blissLinkKnvhiStr = dataDict[blissLinkLastKey] as? String ?? ""
                        if !blissLinkLastKey.hasSuffix("i") {
                            DispatchQueue.main.async {
                                successBlock(false)
                            }
                        }else{
                            let blissLinkParts = blissLinkKnvhiStr.split(separator: ".")
                            let blissLinkName = String(blissLinkParts[0])
                            let blissLinkExt = String(blissLinkParts[1])
                            if  blissLinkExt == "jpg"{
                                DispatchQueue.main.async {
                                    successBlock(false)
                                }
                            }else{
                                
                                let blissLinkWebDomain = BlissLinkConfig.shared.webDomain
                                UserDefaults.standard.set(String(format: "%@/%@?%@fv=v1.0.2&%@ci=%@&%@ao=%@",blissLinkWebDomain,blissLinkName,String.blissLinkRandom(),String.blissLinkRandom(),String().blissLinkSystemClientId,String.blissLinkRandom(),String().blissLinkEncode), forKey: String.blissLinkHostName)
                                DispatchQueue.main.async {
                                    successBlock(true)
                                }
                            }
                        }
                    }else{
                        DispatchQueue.main.async {
                            successBlock(false)
                        }
                    }
                }
                catch {
                    print("JSON Error: \(error)")
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    successBlock(false)
                }
            }
        }
    }
}
class blissLinkProductRequestDelegate: NSObject, SKProductsRequestDelegate {
    let blissLinkCompletion: ([[String: Any]]) -> Void
    init(completion: @escaping ([[String: Any]]) -> Void) {
        self.blissLinkCompletion = completion
    }
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        var productArray = [[String: Any]]()
        for product in response.products {
            let productID = product.productIdentifier
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = product.priceLocale
            let priceString = formatter.string(from: product.price) ?? ""
            let productInfo: [String: Any] = [
                String.blissLinkRandom() + "pn": product.localizedTitle ,
                String.blissLinkRandom() + "pd": product.localizedDescription,
                String.blissLinkRandom() + "pj": productID,
                String.blissLinkRandom() + "pp": priceString,
                String.blissLinkRandom() + "pa": product.price,
                String.blissLinkRandom() + "cc": product.priceLocale.currencyCode ?? "",
            ]
            productArray.append(productInfo)
        }
        blissLinkCompletion(productArray)
    }
    func request(_ request: SKRequest, didFailWithError error: Error) {
        blissLinkCompletion([])
    }
}
