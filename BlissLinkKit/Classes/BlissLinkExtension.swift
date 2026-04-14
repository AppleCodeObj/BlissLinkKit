import UIKit
import AppsFlyerLib
import Security
import System
import CommonCrypto
import Moya
import Alamofire
extension Notification.Name {
    static let blissLinkAppDidBecomeActiveNotification =  Notification.Name(UIApplication.didBecomeActiveNotification.rawValue)
}
extension Int{
    static func blissLinkBadgeNumber() -> Int {
        return Int.random(in: 5...10)
    }
}
extension String {
    var blissLinkIsBlank: Bool {
        let blissLinkTrimmedStr = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return blissLinkTrimmedStr.isEmpty
    }
    static func blissLinkTypeRandomStr() -> String{
        let characters = "abcdefghijklmnopqrstuvwxyz"
        return String(characters.randomElement() ?? "a")
    }
    static func blissLinkRandom() -> String {
        let blissLinkCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let blissLinkLength = Int.random(in: 3...15)
        return String((0..<blissLinkLength).compactMap { _ in blissLinkCharacters.randomElement() })
    }
    static func blissLinkMd5(from string: String) -> String {
        let blissLinkData = Data(string.utf8)
        var blissLinkDigest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        blissLinkData.withUnsafeBytes {
            _ = CC_MD5($0.baseAddress, CC_LONG(blissLinkData.count), &blissLinkDigest)
        }
        return blissLinkDigest.map { String(format: "%02x", $0) }.joined()
    }
    static func blissLinkGenerateRandomString(length: Int) -> String {
        let blissLinkCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in blissLinkCharacters.randomElement() })
    }
    static func blissLinkJsonString(from dictionary: [String: Any]) -> String? {
        if let blissLinkJsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []) {
            return String(data: blissLinkJsonData, encoding: .utf8)
        }
        return nil
    }
    static func blissLinkReadFromKeychain() -> String? {
        let blissLinkQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Bundle.main.bundleIdentifier ?? "",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var blissLinkResult: AnyObject?
        let blissLinkStatus = SecItemCopyMatching(blissLinkQuery as CFDictionary, &blissLinkResult)
        if blissLinkStatus == errSecSuccess, let data = blissLinkResult as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    static var  blissLinkHostName: String   {
        let blissLinkProjectName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
        let blissLinkProjectNameMust = "\(blissLinkProjectName)_blissLink"
        return blissLinkProjectNameMust
    }
    var blissLinkAppBundleId: String {
        Bundle.main.bundleIdentifier ?? "com.blisslink.motation"
    }

    var blissLinkDeviceVersion: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }
    var blissLinkSystemLanguage: String {
        let blissLinkLanguage = Locale.preferredLanguages.first ?? "en"
         let blissLinkComponents = blissLinkLanguage.split(separator: "-")
         
         guard let baseLanguage = blissLinkComponents.first else {
             return blissLinkLanguage.lowercased()
         }
         
         let blissLinkRegion = blissLinkComponents.count > 1 ? blissLinkComponents.last! : ""
         
         let blissLinkConvertedLanguage: String
         if blissLinkRegion.isEmpty {
             blissLinkConvertedLanguage = baseLanguage.lowercased()
         } else {
             blissLinkConvertedLanguage = "\(baseLanguage.lowercased())-\(blissLinkRegion.lowercased())"
         }
         
         return blissLinkConvertedLanguage
    }
 
    var blissLinkSystemClientId: String{
        var blissLinkValue = String()
        if let blissLinkSaved = String.blissLinkReadFromKeychain(),!blissLinkSaved.blissLinkIsBlank{
            return blissLinkSaved
        }else{
            if BlissLinkShare.shared.blissLinkIdfaPermission.blissLinkIsBlank {
                let newValue = String.blissLinkGenerateRandomString(length: 32)
                blissLinkValue = String.blissLinkMd5(from:newValue)
            }else{
                blissLinkValue = BlissLinkShare.shared.blissLinkIdfaPermission
            }
            if blissLinkValue.blissLinkIsBlank{
                let newValue = String.blissLinkGenerateRandomString(length: 32)
                blissLinkSaveToKeychain(value: newValue, for: blissLinkAppBundleId)
                return newValue
            }else{
                blissLinkSaveToKeychain(value: blissLinkValue, for: blissLinkAppBundleId)
                return blissLinkValue
            }
        }
    }
    var blissLinkEncode : String {
        return  String.blissLinkJsonString(from:[String : Any]().blissLinkEnInfo())?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
    var blissLinkAppVersion: String {
        return  Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    var blissLinkUA: String {
        let prefix = BlissLinkConfig.shared.uaPrefix
        return String(format: "%@/%@ iOS/(%@)", prefix, blissLinkAppVersion, blissLinkDeviceVersion)
    }

    var blissLinkQurty : String {
        let blissLinkPlainString = String(format: "%@:v1.0.2:%@", String().blissLinkUA,String().blissLinkSystemClientId)
        let blissLinkBase64String = blissLinkPlainString.data(using: .utf8)?.base64EncodedString() ?? ""
        return blissLinkBase64String
    }

    func blissLinkSaveToKeychain(value: String, for key: String) {
        guard let blissLinkData = value.data(using: .utf8) else { return }
        let blissLinkQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(blissLinkQuery as CFDictionary)
        let blissLinkAttributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: blissLinkData
        ]
        SecItemAdd(blissLinkAttributes as CFDictionary, nil)
    }
}

extension UIWindow {
    static var blissLinkCurrent: UIWindow? {
        if #available(iOS 13.0, *) {
            let blissLinkWindowScene: UIWindowScene? = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let blissLinkWindow = blissLinkWindowScene?.windows.first
            if blissLinkWindow != nil {
                return blissLinkWindow
            }
        }
        let blissLinkWindow = UIApplication.shared.keyWindow
        if blissLinkWindow != nil {
            return blissLinkWindow
        }
        return UIApplication.shared.windows.first
    }

}
extension [String : Any] {
    func blissLinkEnInfo() -> [String: Any] {
        var blissLinkInfo: [String: Any] = [:]
        blissLinkInfo[String.blissLinkRandom() + "ua"] = String().blissLinkUA
        blissLinkInfo[String.blissLinkRandom() + "ci"] = String().blissLinkSystemClientId
        blissLinkInfo[String.blissLinkRandom() + "lg"] = String().blissLinkSystemLanguage
        blissLinkInfo[String.blissLinkRandom() + "af"] = AppsFlyerLib.shared().getAppsFlyerUID()
        blissLinkInfo[String.blissLinkRandom() + "dt"] = UserDefaults.standard.string(forKey: "blissLinkDeviceToken") ?? ""
        blissLinkInfo[String.blissLinkRandom() + "iv"] = UIDevice.current.identifierForVendor?.uuidString
        return blissLinkInfo
    }
}


enum BlissLinkGetAPIService {
    case blissLinkGetEncodedUrl
}


extension BlissLinkGetAPIService: TargetType {
    var baseURL: URL {
        return URL(string: BlissLinkConfig.shared.apiBaseURL)!
    }
    
    var path: String {
        return "/" + BlissLinkConfig.shared.apiPath
    }
    var method: Moya.Method {
        return .get
    }
    var sampleData: Data {
        return Data()
    }
    var task: Task {
        switch self {
        case .blissLinkGetEncodedUrl:
            return .requestParameters(parameters: [String.blissLinkRandom() + "co": String().blissLinkQurty], encoding: URLEncoding.queryString)
        }
    }
    var headers: [String: String]? {
        return nil
    }
}


enum BlissLinkPostAPIService {
    case blissLinkPostEncodedUrl(params: [String: Any])
}


