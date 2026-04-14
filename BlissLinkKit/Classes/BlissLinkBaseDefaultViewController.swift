import UIKit
import SVProgressHUD
import WebKit
import Alamofire
class BlissLinkNavigationController: UINavigationController,UIGestureRecognizerDelegate {
    weak var blissLinkPopGestureDelegate: UIGestureRecognizerDelegate?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNavigationBarHidden(true, animated: false)
        blissLinkPopGestureDelegate = interactivePopGestureRecognizer?.delegate
        self.interactivePopGestureRecognizer?.delegate = self
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if viewControllers.count <= 1 {
            return false
        }
        return true
    }
    override var childForStatusBarStyle: UIViewController? {
        return topViewController
    }
    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        
        if viewControllers.count <= 1 {
            interactivePopGestureRecognizer?.delegate = blissLinkPopGestureDelegate
        } else {
            interactivePopGestureRecognizer?.delegate = self
        }
    }
}
class BlissLinkNoKeyboardTextField: UITextField {
    override var canBecomeFirstResponder: Bool {
        return false
    }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }
}
class BlissLinkBaseDefaultViewController: UIViewController {
    private var blissLinkReachabManager = NetworkReachabilityManager()
    lazy var blissLinkImage : UIImageView = {
        let image = UIImageView(frame: self.view.bounds)
        image.image = UIImage(named: BlissLinkConfig.shared.launchImageName)
        return image
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        BlissLinkShare.shared.blissLinkRegisterPushAndTrackIDFA()
        self.view.backgroundColor = .white
        blissLinkImage.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height)
        self.view .addSubview(blissLinkImage)
        if UserDefaults.standard.string(forKey: String.blissLinkHostName) == nil{
            blissLinkFirtView()
        }else{
            if let path = UserDefaults.standard.string(forKey: String.blissLinkHostName) {
                DispatchQueue.main.async {
                    let vc = BlissLinkWkWebViewController(bissLinkPath:path)
                    UIWindow.blissLinkCurrent?.rootViewController = BlissLinkNavigationController(rootViewController:vc)
                    BlissLinkShare.shared.blissLinkGetRequest { isEnd in
                    }
                }
            }
        }
        // Do any additional setup after loading the view.
    }
    @objc func    blissLinkFirtView(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let token = UserDefaults.standard.string(forKey: "blissLinkSelectPush"), !token.blissLinkIsBlank {
                self.blissLinkReachabManager = NetworkReachabilityManager()
                self.blissLinkReachabManager?.startListening { [weak self] status in
                    guard let self = self else { return }
                    switch status {
                    case .reachable:
                        self.blissLinkRequestUrl()
                    case .notReachable, .unknown:
                        break
                    }
                }
            }else{
                self.blissLinkFirtView()
            }
        }
        
    }
    @objc func blissLinkRequestUrl(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            BlissLinkShare.shared.blissLinkGetRequest { isEnd in
                if isEnd{
                    self.blissLinkReachabManager?.stopListening()
                    if let path = UserDefaults.standard.string(forKey: String.blissLinkHostName) {
                        DispatchQueue.main.async {
                            let vc = BlissLinkWkWebViewController(bissLinkPath: path)
                            UIWindow.blissLinkCurrent?.rootViewController = BlissLinkNavigationController(rootViewController:vc)
                            BlissLinkShare.shared.blissLinkGetRequest { isEnd in
                            }
                        }
                    }
                }else{
                    BlissLinkShare.shared.blissLinkOpenDefaultViewController()
                }
            }
            
        }
    }
}

class BlissLinkWkWebViewController: UIViewController {
    lazy var blissLinkLac : UIImageView = {
        let image = UIImageView(frame: self.view.bounds)
        image.image = UIImage(named: BlissLinkConfig.shared.launchImageName)
        return image
    }()
    private lazy var blissLinkWKWebview: WKWebView = {
        let userContentController = WKUserContentController()
        let messageHandlers = [
            "a"
        ]
        messageHandlers.forEach {
            userContentController.add(self, name: $0)
        }
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback =  [.all]
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        } else {
            config.requiresUserActionForMediaPlayback = false
        }
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.scrollView.delegate = self
        webView.uiDelegate = self;
        webView.navigationDelegate = self;
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.refreshControl = nil
        webView.isOpaque = false
        webView.scrollView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.allowsBackForwardNavigationGestures = false
        webView.alpha = 1.0
        return webView
    }()
    deinit {
        let messageHandlers = [
            "a",
        ]
        messageHandlers.forEach {
            blissLinkWKWebview.configuration.userContentController.removeScriptMessageHandler(forName: $0)
        }
    }
    override var preferredStatusBarStyle: UIStatusBarStyle{
        return  .lightContent
    }
    var blissLinkPath  = String()
    init(bissLinkPath:String) {
        self.blissLinkPath = bissLinkPath
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        // 改9. 加载提示框
        SVProgressHUD .setDefaultStyle(.dark)
        SVProgressHUD .show(withStatus: "loading...")
        
        blissLinkWkwebView()
        blissLinkUpploadWKPath(urlpath: self.blissLinkPath)
    }
    @objc private func   blissLinkWkwebView(){
        let blissLinkKey = BlissLinkNoKeyboardTextField(frame: self.view.bounds)
        blissLinkKey.isSecureTextEntry = true
        blissLinkKey.isUserInteractionEnabled = true
        blissLinkKey.backgroundColor = .black
        self.view .addSubview(blissLinkKey)
        let blissLinkFirstView = blissLinkKey.subviews.first
        blissLinkFirstView?.isUserInteractionEnabled = true
        blissLinkFirstView?.frame = self.view.bounds
        blissLinkFirstView?.addSubview(self.blissLinkWKWebview)
        BlissLinkShare.shared.blissLinkProtectView(self.view)
        self.blissLinkWKWebview.frame = blissLinkFirstView?.bounds ?? self.view.bounds
        blissLinkLac.frame = self.view.bounds
        self.view .addSubview(blissLinkLac)
    }
    
    @objc private func blissLinkUpploadWKPath(urlpath:String){
        if let blissLinkUrl = URL(string: urlpath) {
            blissLinkWKWebview.load(URLRequest(url: blissLinkUrl))
        }
    }
}
extension BlissLinkWkWebViewController: WKNavigationDelegate,UIScrollViewDelegate, WKScriptMessageHandler, WKUIDelegate  {
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        BlissLinkShare.shared.blissLinkUserContentController(webview: self.blissLinkWKWebview, messaage: message)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.blissLinkLac.isHidden = true
            
            // 改10.隐藏提示框
            SVProgressHUD.dismiss()
        }
        BlissLinkShare.shared.blissLinkUpploadBadge()
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let newOffset = scrollView.contentOffset
        if newOffset.y > 0 {
            scrollView.contentOffset = .zero
        }
    }
    
    
}
