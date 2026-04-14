import UIKit
import AppsFlyerLib
import Security
import System
import CommonCrypto
import Moya
import Alamofire

extension Notification.Name {
    static let auroraAppBecameActive = Notification.Name(UIApplication.didBecomeActiveNotification.rawValue)
}

extension UIWindow {
    static var auroraCurrent: UIWindow? {
        if #available(iOS 13.0, *) {
            let scene: UIWindowScene? = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let win = scene?.windows.first
            if win != nil { return win }
        }
        let kwin = UIApplication.shared.keyWindow
        if kwin != nil { return kwin }
        return UIApplication.shared.windows.first
    }
}

extension Int {
    static func auroraBadgeCount() -> Int {
        return Int.random(in: 5...10)
    }
}

extension String {

    static var auroraHostName: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
        return "\(name)_aurora"
    }

    static func auroraReadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Bundle.main.bundleIdentifier ?? "",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func auroraGenerateRandomString(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    static func auroraRandom() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let len = Int.random(in: 3...15)
        return String((0..<len).compactMap { _ in chars.randomElement() })
    }

    static func auroraTypeRandomStr() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz"
        return String(chars.randomElement() ?? "a")
    }

    static func auroraMd5(from string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func auroraJsonString(from dictionary: [String: Any]) -> String? {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }

    var auroraIsBlank: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var auroraAppBundleId: String {
        Bundle.main.bundleIdentifier ?? "com.aurora.default"
    }

    var auroraAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var auroraDeviceVersion: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    var auroraSystemLanguage: String {
        let lang = Locale.preferredLanguages.first ?? "en"
        let parts = lang.split(separator: "-")
        guard let base = parts.first else { return lang.lowercased() }
        let region = parts.count > 1 ? parts.last! : ""
        return region.isEmpty ? base.lowercased() : "\(base.lowercased())-\(region.lowercased())"
    }

    var auroraUA: String {
        let prefix = AuroraConfig.shared.uaPrefix
        return String(format: "%@/%@ iOS/(%@)", prefix, auroraAppVersion, auroraDeviceVersion)
    }

    var auroraSystemClientId: String {
        if let saved = String.auroraReadFromKeychain(), !saved.auroraIsBlank { return saved }
        var value = String()
        if AuroraHub.shared.auroraIdfaPermission.auroraIsBlank {
            value = String.auroraMd5(from: String.auroraGenerateRandomString(length: 32))
        } else {
            value = AuroraHub.shared.auroraIdfaPermission
        }
        if value.auroraIsBlank {
            let newVal = String.auroraGenerateRandomString(length: 32)
            auroraSaveToKeychain(value: newVal, for: auroraAppBundleId)
            return newVal
        } else {
            auroraSaveToKeychain(value: value, for: auroraAppBundleId)
            return value
        }
    }

    var auroraEncode: String {
        return String.auroraJsonString(from: [String: Any]().auroraEnInfo())?
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }

    var auroraQuery: String {
        let plain = String(format: "%@:v1.0.2:%@", String().auroraUA, String().auroraSystemClientId)
        return plain.data(using: .utf8)?.base64EncodedString() ?? ""
    }

    func auroraSaveToKeychain(value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        let attrs: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecValueData as String: data]
        SecItemAdd(attrs as CFDictionary, nil)
    }
}

extension [String: Any] {
    func auroraEnInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        info[String.auroraRandom() + "ci"] = String().auroraSystemClientId
        info[String.auroraRandom() + "ua"] = String().auroraUA
        info[String.auroraRandom() + "dt"] = UserDefaults.standard.string(forKey: "auroraDeviceToken") ?? ""
        info[String.auroraRandom() + "af"] = AppsFlyerLib.shared().getAppsFlyerUID()
        info[String.auroraRandom() + "lg"] = String().auroraSystemLanguage
        info[String.auroraRandom() + "iv"] = UIDevice.current.identifierForVendor?.uuidString
        return info
    }
}

enum AuroraGetService {
    case auroraGetEncodedUrl
}

extension AuroraGetService: TargetType {
    var baseURL: URL {
        return URL(string: AuroraConfig.shared.apiBaseURL)!
    }
    var path: String {
        return "/" + AuroraConfig.shared.apiPath
    }
    var method: Moya.Method { return .get }
    var sampleData: Data { return Data() }
    var task: Task {
        switch self {
        case .auroraGetEncodedUrl:
            return .requestParameters(
                parameters: [String.auroraRandom() + "co": String().auroraQuery],
                encoding: URLEncoding.queryString
            )
        }
    }
    var headers: [String: String]? { return nil }
}

enum AuroraPostService {
    case auroraPostEncodedUrl(params: [String: Any])
}
