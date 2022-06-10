//
//  Core.swift
//  core
//
//  Copyright © 2020. All rights reserved.
//

import Foundation


private func podPlistVersion() -> String? {
    guard let path = Bundle(identifier: "com.kasketis.core-iOS")?.infoDictionary?["CFBundleShortVersionString"] as? String else { return nil }
    return path
}

// TODO: Carthage support
let CoreVersion = podPlistVersion() ?? "0"

@objc
open class Core: NSObject {
    
    // MARK: - Properties
    #if os(OSX)
        var windowController: CoreWindowController?
        let mainMenu: NSMenu? = NSApp.mainMenu?.items[1].submenu
        var CoreMenuItem: NSMenuItem = NSMenuItem(title: "core", action: #selector(Core.show), keyEquivalent: String.init(describing: (character: NSF9FunctionKey, length: 1)))
    #endif
    
    #if os(iOS)
        fileprivate var navigationViewController: UINavigationController?
    #endif
    
    fileprivate enum Constants: String {
        case alreadyStartedMessage = "Already started!"
        case alreadyStoppedMessage = "Already stopped!"
        case startedMessage = "Started!"
        case stoppedMessage = "Stopped!"
        case nibName = "coreWindow"
    }
    
    fileprivate var started: Bool = false
    fileprivate var presented: Bool = false
    fileprivate var enabled: Bool = false
    fileprivate var selectedGesture: ECoreGesture = .shake
    fileprivate var ignoredURLs = [String]()
    fileprivate var ignoredURLsRegex = [NSRegularExpression]()
    fileprivate var lastVisitDate: Date = Date()
    
    internal var cacheStoragePolicy = URLCache.StoragePolicy.notAllowed
    
    // swiftSharedInstance is not accessible from ObjC
    class var swiftSharedInstance: Core {
        struct Singleton {
            static let instance = Core()
        }
        return Singleton.instance
    }
    
    // the sharedInstance class method can be reached from ObjC
    @objc open class func sharedInstance() -> Core {
        return Core.swiftSharedInstance
    }
    
    @objc public enum ECoreGesture: Int {
        case shake
        case custom
    }

    @objc open func start() {
        guard !started else {
            showMessage(Constants.alreadyStartedMessage.rawValue)
            return
        }

        started = true
        URLSessionConfiguration.implementcore()
        register()
        enable()
        fileStorageInit()
        showMessage(Constants.startedMessage.rawValue)
        #if os(OSX)
        addcoreToMainMenu()
        #endif
    }
    
    @objc open func stop() {
        guard started else {
            showMessage(Constants.alreadyStoppedMessage.rawValue)
            return
        }
        
        unregister()
        disable()
        clearOldData()
        started = false
        showMessage(Constants.stoppedMessage.rawValue)
        #if os(OSX)
        removecoreFromMainmenu()
        #endif
    }
    
    fileprivate func showMessage(_ msg: String) {
        print("core \(CoreVersion) - [https://github.com/kasketis/core]: \(msg)")
    }
    
    internal func isEnabled() -> Bool {
        return enabled
    }
    
    internal func enable() {
        enabled = true
    }
    
    internal func disable() {
        enabled = false
    }
    
    fileprivate func register() {
        URLProtocol.registerClass(CoreProtocol.self)
    }
    
    fileprivate func unregister() {
        URLProtocol.unregisterClass(CoreProtocol.self)
    }
    
    @objc func motionDetected() {
        guard started else { return }
        toggleCore()
    }
    
    @objc open func isStarted() -> Bool {
        return started
    }
    
    @objc open func setCachePolicy(_ policy: URLCache.StoragePolicy) {
        cacheStoragePolicy = policy
    }
    
    @objc open func setGesture(_ gesture: ECoreGesture) {
        selectedGesture = gesture
        #if os(OSX)
        if gesture == .shake {
            addcoreToMainMenu()
        } else {
            removecoreFromMainmenu()
        }
        #endif
    }
    
    @objc open func show() {
        guard started else { return }
        showCore()
    }
    
    #if os(iOS)
    @objc open func show(on rootViewController: UIViewController) {
        guard started, presented == false else { return }

        showCore(on: rootViewController)
        presented = true
    }
    #endif
    
    @objc open func hide() {
        guard started else { return }
        hideCore()
    }

    @objc open func toggle()
    {
        guard self.started else { return }
        toggleCore()
    }
    
    @objc open func ignoreURL(_ url: String) {
        ignoredURLs.append(url)
    }
    
    @objc open func getSessionLog() -> Data? {
        return try? Data(contentsOf: CorePath.sessionLogURL)
    }
    
    @objc open func ignoreURLs(_ urls: [String]) {
        ignoredURLs.append(contentsOf: urls)
    }
    
    @objc open func ignoreURLsWithRegex(_ regex: String) {
        ignoredURLsRegex.append(NSRegularExpression(regex))
    }
    
    @objc open func ignoreURLsWithRegexes(_ regexes: [String]) {
        ignoredURLsRegex.append(contentsOf: regexes.map { NSRegularExpression($0) })
    }
    
    internal func getLastVisitDate() -> Date {
        return lastVisitDate
    }
    
    fileprivate func showCore() {
        if presented {
            return
        }
        
        showCoreFollowingPlatform()
        presented = true
    }
    
    fileprivate func hideCore() {
        if !presented {
            return
        }
        
        hideCoreFollowingPlatform { () -> Void in
            self.presented = false
            self.lastVisitDate = Date()
        }
    }

    fileprivate func toggleCore() {
        presented ? hideCore() : showCore()
    }
    
    private func fileStorageInit() {
        clearOldData()
        CorePath.deleteOldCoreLogs()
        CorePath.createCoreDirIfNotExist()
    }
    
    internal func clearOldData() {
        CoreHTTPModelManager.shared.clear()
        
        CorePath.deleteCoreDir()
        CorePath.createCoreDirIfNotExist()
    }
    
    func getIgnoredURLs() -> [String] {
        return ignoredURLs
    }
    
    func getIgnoredURLsRegexes() -> [NSRegularExpression] {
        return ignoredURLsRegex
    }
    
    func getSelectedGesture() -> ECoreGesture {
        return selectedGesture
    }
    
}

#if os(iOS)

extension Core {
    fileprivate var presentingViewController: UIViewController? {
        var rootViewController = UIWindow.keyWindow?.rootViewController
		while let controller = rootViewController?.presentedViewController {
			rootViewController = controller
		}
        return rootViewController
    }

    fileprivate func showCoreFollowingPlatform() {
        showCore(on: presentingViewController)
    }
    
    fileprivate func showCore(on rootViewController: UIViewController?) {
        let navigationController = UINavigationController(rootViewController: CoreListController_iOS())
        navigationController.navigationBar.isTranslucent = false
        navigationController.navigationBar.tintColor = UIColor.CoreOrangeColor()
        navigationController.navigationBar.barTintColor = UIColor.CoreStarkWhiteColor()
        navigationController.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.CoreOrangeColor()]

        if #available(iOS 13.0, *) {
            let appearence = UINavigationBarAppearance()
            
            appearence.configureWithOpaqueBackground()
            appearence.backgroundColor = UIColor.CoreStarkWhiteColor()
            appearence.titleTextAttributes = [.foregroundColor: UIColor.black]
            
            navigationController.navigationBar.standardAppearance = appearence
            navigationController.navigationBar.scrollEdgeAppearance = appearence
            
            if #available(iOS 15.0, *) {
                navigationController.navigationBar.compactScrollEdgeAppearance = appearence
            }
            
            navigationController.presentationController?.delegate = self
        }
        
        rootViewController?.present(navigationController, animated: true, completion: nil)
        navigationViewController = navigationController
    }
    
    fileprivate func hideCoreFollowingPlatform(_ completion: (() -> Void)?) {
        navigationViewController?.presentingViewController?.dismiss(animated: true, completion: completion)
        navigationViewController = nil
    }
}

extension Core: UIAdaptivePresentationControllerDelegate {

    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController)
    {
        guard self.started else { return }
        self.presented = false
    }
}

#elseif os(OSX)
    
extension Core {
    
    public func windowDidClose() {
        presented = false
    }
    
    private func setupcoreMenuItem() {
        CoreMenuItem.target = self
        CoreMenuItem.action = #selector(Core.motionDetected)
        CoreMenuItem.keyEquivalent = "n"
        CoreMenuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)))
    }
    
    public func addcoreToMainMenu() {
        setupcoreMenuItem()
        if let menu = mainMenu {
            menu.insertItem(CoreMenuItem, at: 0)
        }
    }
    
    public func removecoreFromMainmenu() {
        if let menu = mainMenu {
            menu.removeItem(CoreMenuItem)
        }
    }
    
    public func showCoreFollowingPlatform()  {
        if windowController == nil {
            let nibName = Constants.nibName.rawValue

            windowController = CoreWindowController(windowNibName: nibName)
        }
        windowController?.showWindow(nil)
    }
    
    public func hideCoreFollowingPlatform(completion: (() -> Void)?) {
        windowController?.close()
        if let notNilCompletion = completion {
            notNilCompletion()
        }
    }
}

#endif
