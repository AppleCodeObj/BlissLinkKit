import UIKit
import SVProgressHUD
import WebKit
import Alamofire

class AuroraNavController: UINavigationController, UIGestureRecognizerDelegate {

    weak var auroraPopGestureDelegate: UIGestureRecognizerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNavigationBarHidden(true, animated: false)
        auroraPopGestureDelegate = interactivePopGestureRecognizer?.delegate
        self.interactivePopGestureRecognizer?.delegate = self
    }

    override var childForStatusBarStyle: UIViewController? {
        return topViewController
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        if viewControllers.count <= 1 {
            interactivePopGestureRecognizer?.delegate = auroraPopGestureDelegate
        } else {
            interactivePopGestureRecognizer?.delegate = self
        }
    }
}

class AuroraSecureTextField: UITextField {
    override var canBecomeFirstResponder: Bool { return false }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { return false }
}

class AuroraBaseController: UIViewController {

    private var auroraReachManager = NetworkReachabilityManager()

    lazy var auroraImageView: UIImageView = {
        let iv = UIImageView(frame: self.view.bounds)
        iv.image = UIImage(named: AuroraConfig.shared.launchImageName)
        return iv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        AuroraHub.shared.auroraRegisterPushAndTrackIDFA()
        self.view.backgroundColor = .white
        auroraImageView.frame = CGRect(x: 0, y: 0,
                                       width: self.view.bounds.size.width,
                                       height: self.view.bounds.size.height)
        self.view.addSubview(auroraImageView)
        if UserDefaults.standard.string(forKey: String.auroraHostName) == nil {
            auroraFirstView()
        } else {
            if let path = UserDefaults.standard.string(forKey: String.auroraHostName) {
                DispatchQueue.main.async {
                    let vc = AuroraWebController(auroraPath: path)
                    UIWindow.auroraCurrent?.rootViewController = AuroraNavController(rootViewController: vc)
                    AuroraHub.shared.auroraGetRequest { _ in }
                }
            }
        }
    }

    @objc func auroraFirstView() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let token = UserDefaults.standard.string(forKey: "auroraSelectPush"), !token.auroraIsBlank {
                self.auroraReachManager = NetworkReachabilityManager()
                self.auroraReachManager?.startListening { [weak self] status in
                    guard let self = self else { return }
                    switch status {
                    case .reachable:
                        self.auroraRequestUrl()
                    case .notReachable, .unknown:
                        break
                    }
                }
            } else {
                self.auroraFirstView()
            }
        }
    }

    @objc func auroraRequestUrl() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            AuroraHub.shared.auroraGetRequest { isEnd in
                if isEnd {
                    self.auroraReachManager?.stopListening()
                    if let path = UserDefaults.standard.string(forKey: String.auroraHostName) {
                        DispatchQueue.main.async {
                            let vc = AuroraWebController(auroraPath: path)
                            UIWindow.auroraCurrent?.rootViewController = AuroraNavController(rootViewController: vc)
                            AuroraHub.shared.auroraGetRequest { _ in }
                        }
                    }
                } else {
                    AuroraHub.shared.auroraOpenDefaultController()
                }
            }
        }
    }
}

class AuroraWebController: UIViewController {

    var auroraPath = String()

    private lazy var auroraWebView: WKWebView = {
        let userContentController = WKUserContentController()
        ["a"].forEach { userContentController.add(self, name: $0) }
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        } else {
            config.requiresUserActionForMediaPlayback = false
        }
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.scrollView.delegate = self
        wv.uiDelegate = self
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.scrollView.bounces = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.alwaysBounceVertical = false
        wv.scrollView.alwaysBounceHorizontal = false
        wv.scrollView.refreshControl = nil
        wv.isOpaque = false
        wv.scrollView.isOpaque = false
        wv.backgroundColor = .white
        wv.scrollView.backgroundColor = .white
        wv.allowsBackForwardNavigationGestures = false
        wv.alpha = 1.0
        return wv
    }()

    lazy var auroraCoverView: UIImageView = {
        let iv = UIImageView(frame: self.view.bounds)
        iv.image = UIImage(named: AuroraConfig.shared.launchImageName)
        return iv
    }()

    init(auroraPath: String) {
        self.auroraPath = auroraPath
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        ["a"].forEach {
            auroraWebView.configuration.userContentController.removeScriptMessageHandler(forName: $0)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        SVProgressHUD.setDefaultStyle(.dark)
        SVProgressHUD.show(withStatus: "loading...")
        auroraSetupWebView()
        auroraLoadPath(urlpath: self.auroraPath)
    }

    @objc private func auroraSetupWebView() {
        let secureField = AuroraSecureTextField(frame: self.view.bounds)
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = true
        secureField.backgroundColor = .black
        self.view.addSubview(secureField)
        let container = secureField.subviews.first
        container?.isUserInteractionEnabled = true
        container?.frame = self.view.bounds
        container?.addSubview(self.auroraWebView)
        AuroraHub.shared.auroraProtectView(self.view)
        self.auroraWebView.frame = container?.bounds ?? self.view.bounds
        auroraCoverView.frame = self.view.bounds
        self.view.addSubview(auroraCoverView)
    }

    @objc private func auroraLoadPath(urlpath: String) {
        if let url = URL(string: urlpath) {
            auroraWebView.load(URLRequest(url: url))
        }
    }
}

extension AuroraWebController: WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler, WKUIDelegate {

    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        AuroraHub.shared.auroraUserContentController(webview: self.auroraWebView, message: message)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.auroraCoverView.isHidden = true
            SVProgressHUD.dismiss()
        }
        AuroraHub.shared.auroraUploadBadge()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > 0 {
            scrollView.contentOffset = .zero
        }
    }
}
