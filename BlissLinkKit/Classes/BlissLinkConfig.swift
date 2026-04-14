import UIKit

/// BlissLinkKit 全局配置，在 App 启动时调用 BlissLinkConfig.shared.setup(...) 完成初始化
public class BlissLinkConfig {

    public static let shared = BlissLinkConfig()
    private init() {}

    // MARK: - AppsFlyer
    /// AppsFlyer Dev Key（来自 AppsFlyer 后台）
    public var appsFlyerDevKey: String = ""
    /// Apple App ID（来自 App Store Connect，纯数字字符串）
    public var appleAppID: String = ""

    // MARK: - UI
    /// 启动页图片名称（xcassets 中的图片 key）
    public var launchImageName: String = ""
    /// 打开 A 面（主工程默认页）的回调，由宿主 App 实现
    public var openDefaultViewControllerHandler: (() -> Void)?

    // MARK: - Network
    /// Moya 请求的 baseURL，例如 "https://vwi0bc.jp9rw.com"
    public var apiBaseURL: String = ""
    /// Moya 请求的 path，例如 "z8ubva"
    public var apiPath: String = ""
    /// 网页落地页域名，例如 "https://dk9hk8.jp9rw.com"
    public var webDomain: String = ""
    /// UA 字符串中的 App 标识前缀，例如 "mvdca"
    public var uaPrefix: String = ""

    // MARK: - RevenueCat
    /// RevenueCat API Key（来自 RevenueCat 后台）
    public var revenueCatKey: String = ""

    // MARK: - 一键配置
    /// 在 AppDelegate / SceneDelegate 中调用此方法完成所有参数初始化
    public func setup(
        appsFlyerDevKey: String,
        appleAppID: String,
        launchImageName: String,
        apiBaseURL: String,
        apiPath: String,
        webDomain: String,
        uaPrefix: String,
        revenueCatKey: String,
        openDefaultViewControllerHandler: @escaping () -> Void
    ) {
        self.appsFlyerDevKey = appsFlyerDevKey
        self.appleAppID = appleAppID
        self.launchImageName = launchImageName
        self.apiBaseURL = apiBaseURL
        self.apiPath = apiPath
        self.webDomain = webDomain
        self.uaPrefix = uaPrefix
        self.revenueCatKey = revenueCatKey
        self.openDefaultViewControllerHandler = openDefaultViewControllerHandler
    }
}
