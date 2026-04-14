import UIKit

public class AuroraConfig {

    public static let shared = AuroraConfig()
    private init() {}

    // MARK: - Network
    public var apiBaseURL: String = ""
    public var webDomain: String = ""
    public var uaPrefix: String = ""
    public var apiPath: String = ""

    // MARK: - RevenueCat
    public var revenueCatKey: String = ""

    // MARK: - AppsFlyer
    public var appleAppID: String = ""
    public var appsFlyerDevKey: String = ""

    // MARK: - UI
    /// A 面入口 ViewController 工厂，由宿主 App 提供
    public var defaultViewControllerProvider: (() -> UIViewController)?
    public var launchImageName: String = ""

    // MARK: - Setup
    public func setup(
        appsFlyerDevKey: String,
        appleAppID: String,
        launchImageName: String,
        apiBaseURL: String,
        apiPath: String,
        webDomain: String,
        uaPrefix: String,
        revenueCatKey: String,
        defaultViewControllerProvider: @escaping () -> UIViewController
    ) {
        self.apiBaseURL = apiBaseURL
        self.apiPath = apiPath
        self.webDomain = webDomain
        self.uaPrefix = uaPrefix
        self.appsFlyerDevKey = appsFlyerDevKey
        self.appleAppID = appleAppID
        self.revenueCatKey = revenueCatKey
        self.launchImageName = launchImageName
        self.defaultViewControllerProvider = defaultViewControllerProvider
    }
}
