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

class AuroraHub: NSObject {

    static let shared = AuroraHub()

    var auroraIdfaPermission: String = ""
    let auroraGetProvider = MoyaProvider<AuroraGetService>()
    var auroraTrackingPermission: Int? = nil
    var auroraShieldOverlay = UIView()
    var auroraTargetView = UIView()

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(auroraHandleScreenRecordingChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - AppDelegate 转发入口

    /// 在 AppDelegate didRegisterForRemoteNotificationsWithDeviceToken 中调用
    public func auroraDidRegisterDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.setValue(token, forKey: "auroraSelectPush")
    }

    /// 在 AppDelegate open url 中调用
    public func auroraHandleOpen(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) {
        AppsFlyerLib.shared().handleOpen(url, options: options)
    }

    /// 在 AppDelegate open url sourceApplication 中调用
    public func auroraHandleOpen(_ url: URL, sourceApplication: String?, annotation: Any) {
        AppsFlyerLib.shared().handleOpen(url, sourceApplication: sourceApplication, withAnnotation: annotation)
    }

    /// 在 AppDelegate continue userActivity 中调用
    public func auroraContinueUserActivity(_ userActivity: NSUserActivity) {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
    }

    // MARK: - Register

    func auroraRegisterPushAndTrackIDFA() {
        NotificationCenter.default.addObserver(self, selector: #selector(auroraRegisterTrack), name: .auroraAppBecameActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(auroraRegisterApns), name: .auroraAppBecameActive, object: nil)
    }

    @objc func auroraRegisterTrack() {
        AppsFlyerLib.shared().appsFlyerDevKey = AuroraConfig.shared.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = AuroraConfig.shared.appleAppID
        AppsFlyerLib.shared().delegate = self
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        self.auroraTrackingPermission = 1
                        self.auroraIdfaPermission = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                    case .denied, .restricted, .notDetermined:
                        self.auroraTrackingPermission = 0
                        self.auroraIdfaPermission = ""
                    @unknown default:
                        self.auroraTrackingPermission = 0
                        self.auroraIdfaPermission = ""
                    }
                }
            }
        } else {
            if ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
                self.auroraTrackingPermission = 1
                self.auroraIdfaPermission = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            } else {
                self.auroraTrackingPermission = 0
                self.auroraIdfaPermission = ""
            }
        }
        AppsFlyerLib.shared().start()
    }

    @objc func auroraRegisterApns() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {}
        }
    }

    // MARK: - Network

    func auroraGetRequest(successBlock: @escaping (_ isEnd: Bool) -> Void) {
        auroraGetProvider.request(.auroraGetEncodedUrl) { result in
            switch result {
            case .success(let response):
                guard let realData = response.data as? Data else { return }
                do {
                    let json = try JSONSerialization.jsonObject(with: realData) as? [String: Any] ?? [:]
                    guard let code = json["code"],
                          let dataDict = json["data"] as? [String: Any] else { return }
                    if String(format: "%@", code as! CVarArg) == "1003" {
                        let lastKey = dataDict.keys.reversed().first as? String ?? ""
                        let valStr = dataDict[lastKey] as? String ?? ""
                        if !lastKey.hasSuffix("i") {
                            DispatchQueue.main.async { successBlock(false) }
                        } else {
                            let parts = valStr.split(separator: ".")
                            let nameStr = String(parts[0])
                            let extStr = String(parts[1])
                            if extStr == "jpg" {
                                DispatchQueue.main.async { successBlock(false) }
                            } else {
                                let domain = AuroraConfig.shared.webDomain
                                UserDefaults.standard.set(
                                    String(format: "%@/%@?%@fv=v1.0.2&%@ci=%@&%@ao=%@",
                                           domain, nameStr,
                                           String.auroraRandom(), String.auroraRandom(),
                                           String().auroraSystemClientId,
                                           String.auroraRandom(), String().auroraEncode),
                                    forKey: String.auroraHostName
                                )
                                DispatchQueue.main.async { successBlock(true) }
                            }
                        }
                    } else {
                        DispatchQueue.main.async { successBlock(false) }
                    }
                } catch {
                    print("JSON Error: \(error)")
                }
            case .failure:
                DispatchQueue.main.async { successBlock(false) }
            }
        }
    }

    // MARK: - Revenue

    func auroraConfigureRevenueCat(_ key: String, _ userID: String) {
        if !userID.auroraIsBlank {
            Purchases.configure(withAPIKey: key, appUserID: userID)
        }
    }

    func auroraStartPay(identifier: String,
                        orderId: String?,
                        callback: @escaping (_ userId: String, _ status: Int, _ orderId: String) -> Void) {
        let orderIdVal = orderId ?? ""
        Purchases.shared.getOfferings { offerings, error in
            if error != nil { callback(Purchases.shared.appUserID, 0, orderIdVal); return }
            guard let offerings = offerings else { callback(Purchases.shared.appUserID, 0, orderIdVal); return }
            if !orderIdVal.isEmpty {
                do { try Purchases.shared.attribution.setAttributes(["order_no": orderIdVal]) }
                catch { print("Failed to set order_no: \(error)") }
            }
            var found = false
            for (_, offering) in offerings.all {
                if offering.identifier == identifier {
                    found = true
                    self.auroraPurchaseSequentially(
                        packages: offering.availablePackages,
                        orderId: orderIdVal,
                        callback: callback,
                        currentIndex: 0
                    )
                    return
                }
                if found { break }
            }
            if !found { callback(Purchases.shared.appUserID, 0, orderIdVal) }
        }
    }

    private func auroraPurchasePackage(_ package: Package,
                                       orderId: String,
                                       callback: @escaping (_ userId: String, _ status: Int, _ orderId: String) -> Void) {
        Purchases.shared.purchase(package: package) { _, _, error, userCancelled in
            var status = 1
            if userCancelled { status = 2 } else if error != nil { status = 0 }
            DispatchQueue.main.async { callback(Purchases.shared.appUserID, status, orderId) }
        }
    }

    private func auroraPurchaseSequentially(packages: [Package],
                                            orderId: String,
                                            callback: @escaping (_ userId: String, _ status: Int, _ orderId: String) -> Void,
                                            currentIndex: Int) {
        guard currentIndex < packages.count else { return }
        auroraPurchasePackage(packages[currentIndex], orderId: orderId) { userId, status, orderId in
            callback(userId, status, orderId)
            if currentIndex + 1 < packages.count {
                self.auroraPurchaseSequentially(packages: packages, orderId: orderId, callback: callback, currentIndex: currentIndex + 1)
            }
        }
    }

    func auroraFetchProducts(_ productIDArray: [String], completion: @escaping ([[String: Any]]) -> Void) {
        let request = SKProductsRequest(productIdentifiers: Set(productIDArray))
        let delegate = AuroraProductDelegate(completion: completion)
        request.delegate = delegate
        objc_setAssociatedObject(request, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        request.start()
    }

    // MARK: - Badge & Default VC

    func auroraUploadBadge() {
        UIApplication.shared.applicationIconBadgeNumber = Int.auroraBadgeCount()
    }

    func auroraOpenDefaultController() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            AuroraConfig.shared.openDefaultViewControllerHandler?()
        }
    }

    // MARK: - Screen Protection

    func auroraProtectView(_ controllerView: UIView) {
        self.auroraTargetView = controllerView
        self.auroraShieldOverlay = UIView(frame: controllerView.bounds)
        self.auroraShieldOverlay.backgroundColor = .black
        self.auroraShieldOverlay.isHidden = true
        self.auroraShieldOverlay.isUserInteractionEnabled = false
        self.auroraShieldOverlay.alpha = 1.0
        controllerView.addSubview(self.auroraShieldOverlay)
        auroraHandleScreenRecordingChange()
    }

    @objc private func auroraHandleScreenRecordingChange() {
        auroraShieldOverlay.isHidden = !UIScreen.main.isCaptured
    }

    // MARK: - WebView JS Bridge

    func auroraUserContentController(webview: WKWebView, message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        let udValues = body.filter { $0.key.hasSuffix("_ud") }
        let taValues = body.filter { $0.key.hasSuffix("_ta") }
        guard let uuid = udValues.first?.value as? String,
              let dataDict = taValues.first?.value as? [String: Any] else { return }
        if message.name == "a" {
            auroraHandleOpenNativeModule(webview: webview, data: dataDict, uuid: uuid)
        }
    }

    func auroraHandleOpenNativeModule(webview: WKWebView, data: [String: Any], uuid: String) {
        let callback = data.first(where: { $0.key.hasSuffix("_cb") })?.value as? String ?? ""
        let type = data.first(where: { $0.key.hasSuffix("_pe") })?.value as? String ?? ""
        let typeStr = String(type.suffix(2))
        if typeStr == "gd" {
            auroraHandleGoods(webview: webview, data: data, uuid: uuid, callback: callback)
        } else if typeStr == "py" {
            auroraHandlePayment(webview: webview, data: data, uuid: uuid, callback: callback)
        } else if typeStr == "sr" {
            auroraHandleStore()
        }
    }

    func auroraHandleGoods(webview: WKWebView, data: [String: Any], uuid: String, callback: String) {
        let ids = data.first(where: { $0.key.hasSuffix("_is") })?.value as? [String] ?? []
        let uu = data.first(where: { $0.key.hasSuffix("_uu") })?.value as? String ?? ""
        auroraConfigureRevenueCat(AuroraConfig.shared.revenueCatKey, uu)
        auroraFetchProducts(ids) { priceDict in
            var dic: [String: Any] = [:]
            dic[String.auroraRandom() + "ud"] = uuid
            dic[String.auroraRandom() + "gd"] = priceDict
            if priceDict.count > 0 {
                DispatchQueue.main.async {
                    let js = String(format: "window.%@('%@',%@)",
                                   String.auroraTypeRandomStr(), callback,
                                   String.auroraJsonString(from: dic) ?? "")
                    webview.evaluateJavaScript(js) { _, _ in }
                }
            }
        }
    }

    func auroraHandlePayment(webview: WKWebView, data: [String: Any], uuid: String, callback: String) {
        let productID = data.first(where: { $0.key.hasSuffix("_pi") })?.value as? String ?? ""
        let orderID = data.first(where: { $0.key.hasSuffix("_no") })?.value as? String ?? ""
        auroraStartPay(identifier: productID, orderId: orderID) { userId, status, orderId in
            var dic: [String: Any] = [:]
            dic[String.auroraRandom() + "ru"] = userId
            dic[String.auroraRandom() + "ud"] = uuid
            dic[String.auroraRandom() + "us"] = status
            dic[String.auroraRandom() + "no"] = orderId
            let js = String(format: "window.%@('%@',%@)",
                            String.auroraTypeRandomStr(), callback,
                            String.auroraJsonString(from: dic) ?? "")
            webview.evaluateJavaScript(js) { _, _ in }
        }
    }

    func auroraHandleStore() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            if #available(iOS 14.0, *) {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}

extension AuroraHub: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {}
    func onConversionDataFail(_ error: Error) {}
}

class AuroraProductDelegate: NSObject, SKProductsRequestDelegate {
    let auroraCompletion: ([[String: Any]]) -> Void

    init(completion: @escaping ([[String: Any]]) -> Void) {
        self.auroraCompletion = completion
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        var result = [[String: Any]]()
        for product in response.products {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = product.priceLocale
            let priceStr = formatter.string(from: product.price) ?? ""
            let info: [String: Any] = [
                String.auroraRandom() + "pj": product.productIdentifier,
                String.auroraRandom() + "pp": priceStr,
                String.auroraRandom() + "pn": product.localizedTitle,
                String.auroraRandom() + "cc": product.priceLocale.currencyCode ?? "",
                String.auroraRandom() + "pd": product.localizedDescription,
                String.auroraRandom() + "pa": product.price,
            ]
            result.append(info)
        }
        auroraCompletion(result)
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        auroraCompletion([])
    }
}
