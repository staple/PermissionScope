//
//  PermissionScope.swift
//  PermissionScope
//
//  Created by Nick O'Neill on 4/5/15.
//  Copyright (c) 2015 That Thing in Swift. All rights reserved.
//

import UIKit
import AddressBook
import AVFoundation
import Photos
import Contacts

public typealias statusRequestClosure = (_ status: PermissionStatus) -> Void
public typealias authClosureType      = (_ finished: Bool, _ results: [PermissionResult]) -> Void
public typealias cancelClosureType    = (_ results: [PermissionResult]) -> Void
typealias resultsForConfigClosure     = ([PermissionResult]) -> Void

@objc public class PermissionScope: UIViewController, UIGestureRecognizerDelegate {

    // MARK: UI Parameters
    
    /// Header UILabel with the message "Hey, listen!" by default.
    public var headerLabel                 = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    /// Header UILabel with the message "We need a couple things\r\nbefore you get started." by default.
    public var bodyLabel                   = UILabel(frame: CGRect(x: 0, y: 0, width: 240, height: 70))
    /// Color for the close button's text color.
    public var closeButtonTextColor        = UIColor(red: 0, green: 0.47, blue: 1, alpha: 1)
    /// Color for the permission buttons' text color.
    public var permissionButtonTextColor   = UIColor(red: 0, green: 0.47, blue: 1, alpha: 1)
    /// Color for the permission buttons' border color.
    public var permissionButtonBorderColor = UIColor(red: 0, green: 0.47, blue: 1, alpha: 1)
    /// Width for the permission buttons.
    public var permissionButtonBorderWidth  : CGFloat = 1
    /// Corner radius for the permission buttons.
    public var permissionButtonCornerRadius : CGFloat = 6
    /// Color for the permission labels' text color.
    public var permissionLabelColor:UIColor = .black
    /// Font used for all the UIButtons
    public var buttonFont:UIFont            = .boldSystemFont(ofSize: 14)
    /// Font used for all the UILabels
    public var labelFont:UIFont             = .systemFont(ofSize: 14)
    /// Close button. By default in the top right corner.
    public var closeButton                  = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 32))
    /// Offset used to position the Close button.
    public var closeOffset                  = CGSize.zero
    /// Color used for permission buttons with authorized status
    public var authorizedButtonColor        = UIColor(red: 0, green: 0.47, blue: 1, alpha: 1)
    /// Color used for permission buttons with unauthorized status. By default, inverse of `authorizedButtonColor`.
    public var unauthorizedButtonColor:UIColor?
    /// Messages for the body label of the dialog presented when requesting access.
    lazy var permissionMessages: [PermissionType : String] = [PermissionType : String]()
    
    // MARK: View hierarchy for custom alert
    let baseView    = UIView()
    public let contentView = UIView()
    
    /// NSUserDefaults standardDefaults lazy var
    lazy var defaults:UserDefaults = {
        return .standard
    }()

    // MARK: - Internal state and resolution
    
    /// Permissions configured using `addPermission(:)`
    var configuredPermissions: [Permission] = []
    var permissionButtons: [UIButton]       = []
    var permissionLabels: [UILabel]         = []
	
	// Useful for direct use of the request* methods
    
    /// Callback called when permissions status change.
    public var onAuthChange: authClosureType? = nil
    /// Callback called when the user taps on the close button.
    public var onCancel: cancelClosureType?   = nil
    
    /// Called when the user has disabled or denied access to notifications, and we're presenting them with a help dialog.
    public var onDisabledOrDenied: cancelClosureType? = nil
	/// View controller to be used when presenting alerts. Defaults to self. You'll want to set this if you are calling the `request*` methods directly.
	public var viewControllerForAlerts : UIViewController?

    /**
    Checks whether all the configured permission are authorized or not.
    
    - parameter completion: Closure used to send the result of the check.
    */
    func allAuthorized(_ completion: @escaping (Bool) -> Void ) {
        getResultsForConfig{ results in
            let result = results
                .first { $0.status != .authorized }
                .isNil
            completion(result)
        }
    }
    
    /**
    Checks whether all the required configured permission are authorized or not.
    **Deprecated** See issues #50 and #51.
    
    - parameter completion: Closure used to send the result of the check.
    */
    func requiredAuthorized(_ completion: @escaping (Bool) -> Void ) {
        getResultsForConfig{ results in
            let result = results
                .first { $0.status != .authorized }
                .isNil
            completion(result)
        }
    }
    
    // use the code we have to see permission status
    public func permissionStatuses(_ permissionTypes: [PermissionType]?) -> Dictionary<PermissionType, PermissionStatus> {
        var statuses: Dictionary<PermissionType, PermissionStatus> = [:]
        let types: [PermissionType] = permissionTypes ?? PermissionType.allValues
        
        for type in types {
            statusForPermission(type, completion: { status in
                statuses[type] = status
            })
        }
        
        return statuses
    }
    
    /**
    Designated initializer.
    
    - parameter backgroundTapCancels: True if a tap on the background should trigger the dialog dismissal.
    */
    public init(backgroundTapCancels: Bool) {
        super.init(nibName: nil, bundle: nil)

		viewControllerForAlerts = self
		
        // Set up main view
        view.frame = UIScreen.main.bounds
        view.autoresizingMask = [UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleWidth]
        view.backgroundColor = UIColor(red:0, green:0, blue:0, alpha:0.7)
        view.addSubview(baseView)
        // Base View
        baseView.frame = view.frame
        baseView.addSubview(contentView)
        if backgroundTapCancels {
            let tap = UITapGestureRecognizer(target: self, action: #selector(cancel))
            tap.delegate = self
            baseView.addGestureRecognizer(tap)
        }
        // Content View
        contentView.backgroundColor = UIColor.white
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 0.5

        // header label
        headerLabel.font = UIFont.systemFont(ofSize: 22)
        headerLabel.textColor = UIColor.black
        headerLabel.textAlignment = NSTextAlignment.center
        headerLabel.text = "Hey, listen!".localized
        headerLabel.accessibilityIdentifier = "permissionscope.headerlabel"

        contentView.addSubview(headerLabel)

        // body label
        bodyLabel.font = UIFont.boldSystemFont(ofSize: 16)
        bodyLabel.textColor = UIColor.black
        bodyLabel.textAlignment = NSTextAlignment.center
        bodyLabel.text = "We need a couple things\r\nbefore you get started.".localized
        bodyLabel.numberOfLines = 2
        bodyLabel.accessibilityIdentifier = "permissionscope.bodylabel"

        contentView.addSubview(bodyLabel)
        
        // close button
        closeButton.setTitle("Close".localized, for: .normal)
        closeButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        closeButton.accessibilityIdentifier = "permissionscope.closeButton"
        
        contentView.addSubview(closeButton)
    }
    
    /**
    Convenience initializer. Same as `init(backgroundTapCancels: true)`
    */
    public convenience init() {
        self.init(backgroundTapCancels: true)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
    }

    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let screenSize = UIScreen.main.bounds.size
        // Set background frame
        view.frame.size = screenSize
        // Set frames
        let x = (screenSize.width - Constants.UI.contentWidth) / 2

        let dialogHeight: CGFloat
        switch self.configuredPermissions.count {
        case 2:
            dialogHeight = Constants.UI.dialogHeightTwoPermissions
        case 3:
            dialogHeight = Constants.UI.dialogHeightThreePermissions
        default:
            dialogHeight = Constants.UI.dialogHeightSinglePermission
        }
        
        let y = (screenSize.height - dialogHeight) / 2
        contentView.frame = CGRect(x:x, y:y, width:Constants.UI.contentWidth, height:dialogHeight)

        // offset the header from the content center, compensate for the content's offset
        headerLabel.center = contentView.center
        headerLabel.frame.offsetInPlace(dx: -contentView.frame.origin.x, dy: -contentView.frame.origin.y)
        headerLabel.frame.offsetInPlace(dx: 0, dy: -((dialogHeight/2)-50))

        // ... same with the body
        bodyLabel.center = contentView.center
        bodyLabel.frame.offsetInPlace(dx: -contentView.frame.origin.x, dy: -contentView.frame.origin.y)
        bodyLabel.frame.offsetInPlace(dx: 0, dy: -((dialogHeight/2)-100))
        
        closeButton.center = contentView.center
        closeButton.frame.offsetInPlace(dx: -contentView.frame.origin.x, dy: -contentView.frame.origin.y)
        closeButton.frame.offsetInPlace(dx: 105, dy: -((dialogHeight/2)-20))
        closeButton.frame.offsetInPlace(dx: self.closeOffset.width, dy: self.closeOffset.height)
        if let _ = closeButton.imageView?.image {
            closeButton.setTitle("", for: .normal)
        }
        closeButton.setTitleColor(closeButtonTextColor, for: .normal)

        let baseOffset = 95
        var index = 0
        for button in permissionButtons {
            button.center = contentView.center
            button.frame.offsetInPlace(dx: -contentView.frame.origin.x, dy: -contentView.frame.origin.y)
            button.frame.offsetInPlace(dx: 0, dy: -((dialogHeight/2)-160) + CGFloat(index * baseOffset))
            
            let type = configuredPermissions[index].type
            
            statusForPermission(type,
                completion: { currentStatus in
                    let prettyDescription = type.prettyDescription
                    if currentStatus == .authorized {
                        self.setButtonAuthorizedStyle(button)
                        button.setTitle("Allowed \(prettyDescription)".localized.uppercased(), for: .normal)
                    } else if currentStatus == .unauthorized {
                        self.setButtonUnauthorizedStyle(button)
                        button.setTitle("Denied \(prettyDescription)".localized.uppercased(), for: .normal)
                    } else if currentStatus == .disabled {
                        //                setButtonDisabledStyle(button)
                        button.setTitle("\(prettyDescription) Disabled".localized.uppercased(), for: .normal)
                    }
                    
                    let label = self.permissionLabels[index]
                    label.center = self.contentView.center
                    label.frame.offsetInPlace(dx: -self.contentView.frame.origin.x, dy: -self.contentView.frame.origin.y)
                    label.frame.offsetInPlace(dx: 0, dy: -((dialogHeight/2)-205) + CGFloat(index * baseOffset))
                    
                    index = index + 1
            })
        }
    }

    // MARK: - Customizing the permissions
    
    /**
    Adds a permission configuration to PermissionScope.
    
    - parameter config: Configuration for a specific permission.
    - parameter message: Body label's text on the presented dialog when requesting access.
    */
    @objc public func addPermission(_ permission: Permission, message: String) {
        assert(!message.isEmpty, "Including a message about your permission usage is helpful")
        assert(configuredPermissions.count < 3, "Ask for three or fewer permissions at a time")
        assert(configuredPermissions.first { $0.type == permission.type }.isNil, "Permission for \(permission.type) already set")
        
        configuredPermissions.append(permission)
        permissionMessages[permission.type] = message
    }

    /**
    Permission button factory. Uses the custom style parameters such as `permissionButtonTextColor`, `buttonFont`, etc.
    
    - parameter type: Permission type
    
    - returns: UIButton instance with a custom style.
    */
    func permissionStyledButton(_ type: PermissionType) -> UIButton {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 220, height: 40))
        button.setTitleColor(permissionButtonTextColor, for: .normal)
        button.titleLabel?.font = buttonFont

        button.layer.borderWidth = permissionButtonBorderWidth
        button.layer.borderColor = permissionButtonBorderColor.cgColor
        button.layer.cornerRadius = permissionButtonCornerRadius

        button.setTitle("Allow \(type)".localized.uppercased(), for: .normal)
        
        button.addTarget(self, action: Selector("request\(type)"), for: .touchUpInside)

        button.accessibilityIdentifier = "permissionscope.button.\(type)".lowercased()
        
        return button
    }

    /**
    Sets the style for permission buttons with authorized status.
    
    - parameter button: Permission button
    */
    func setButtonAuthorizedStyle(_ button: UIButton) {
        button.layer.borderWidth = 0
        button.backgroundColor = authorizedButtonColor
        button.setTitleColor(.white, for: .normal)
    }
    
    /**
    Sets the style for permission buttons with unauthorized status.
    
    - parameter button: Permission button
    */
    func setButtonUnauthorizedStyle(_ button: UIButton) {
        button.layer.borderWidth = 0
        button.backgroundColor = unauthorizedButtonColor ?? authorizedButtonColor.inverseColor
        button.setTitleColor(.white, for: .normal)
    }

    /**
    Permission label factory, located below the permission buttons.
    
    - parameter type: Permission type
    
    - returns: UILabel instance with a custom style.
    */
    func permissionStyledLabel(_ type: PermissionType) -> UILabel {
        let label  = UILabel(frame: CGRect(x: 0, y: 0, width: 260, height: 50))
        label.font = labelFont
        label.numberOfLines = 2
        label.textAlignment = .center
        label.text = permissionMessages[type]
        label.textColor = permissionLabelColor
        
        return label
    }

    // MARK: - Status and Requests for each permission

    // MARK: Contacts
    
    /**
    Returns the current permission status for accessing Contacts.
    
    - returns: Permission status for the requested type.
    */
    public func statusContacts() -> PermissionStatus {
        if #available(iOS 9.0, *) {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            switch status {
            case .authorized:
                return .authorized
            case .restricted, .denied:
                return .unauthorized
            case .notDetermined:
                return .unknown
            }
        } else {
            // Fallback on earlier versions
            let status = ABAddressBookGetAuthorizationStatus()
            switch status {
            case .authorized:
                return .authorized
            case .restricted, .denied:
                return .unauthorized
            case .notDetermined:
                return .unknown
            }
        }
    }

    /**
    Requests access to Contacts, if necessary.
    */
    public func requestContacts() {
        let status = statusContacts()
        switch status {
        case .unknown:
            if #available(iOS 9.0, *) {
                CNContactStore().requestAccess(for: .contacts, completionHandler: {
                    success, error in
                    self.detectAndCallback()
                })
            } else {
                ABAddressBookRequestAccessWithCompletion(nil) { success, error in
                    self.detectAndCallback()
                }
            }
        case .unauthorized:
            self.showDeniedAlert(.contacts)
        default:
            break
        }
    }

    // MARK: Notifications
    
    /**
    Returns the current permission status for accessing Notifications.
    
    - returns: Permission status for the requested type.
    */
    public func statusNotifications() -> PermissionStatus {
        let settings = UIApplication.shared.currentUserNotificationSettings
        if let settingTypes = settings?.types , settingTypes != UIUserNotificationType() {
            return .authorized
        } else {
            if defaults.bool(forKey: Constants.NSUserDefaultsKeys.requestedNotifications) {
                return .unauthorized
            } else {
                return .unknown
            }
        }
    }
    
    /**
    To simulate the denied status for a notifications permission,
    we track when the permission has been asked for and then detect
    when the app becomes active again. If the permission is not granted
    immediately after becoming active, the user has cancelled or denied
    the request.
    
    This function is called when we want to show the notifications
    alert, kicking off the entire process.
    */
    @objc func showingNotificationPermission() {
        let notifCenter = NotificationCenter.default
        
        notifCenter
            .removeObserver(self,
                            name: NSNotification.Name.UIApplicationWillResignActive,
                            object: nil)
        notifCenter
            .addObserver(self,
                         selector: #selector(finishedShowingNotificationPermission),
                         name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        notificationTimer?.invalidate()
    }
    
    /**
    A timer that fires the event to let us know the user has asked for 
    notifications permission.
    */
    var notificationTimer : Timer?

    /**
    This function is triggered when the app becomes 'active' again after
    showing the notification permission dialog.
    
    See `showingNotificationPermission` for a more detailed description
    of the entire process.
    */
    @objc func finishedShowingNotificationPermission () {
        NotificationCenter.default.removeObserver(self,
            name: NSNotification.Name.UIApplicationWillResignActive,
            object: nil)
        NotificationCenter.default.removeObserver(self,
            name: NSNotification.Name.UIApplicationDidBecomeActive,
            object: nil)
        
        notificationTimer?.invalidate()
        
        defaults.set(true, forKey: Constants.NSUserDefaultsKeys.requestedNotifications)
        defaults.synchronize()

        // callback after a short delay, otherwise notifications don't report proper auth
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(100),
            execute: {
            self.getResultsForConfig { results in
                guard let notificationResult = results.first(where: { $0.type == .notifications })
                    else { return }
                if notificationResult.status == .unknown {
                    self.showDeniedAlert(notificationResult.type)
                } else {
                    self.detectAndCallback()
                }
            }
        })
    }
    
    /**
    Requests access to User Notifications, if necessary.
    */
    public func requestNotifications() {
        let status = statusNotifications()
        switch status {
        case .unknown:
            let notificationsPermission = self.configuredPermissions
                .first { $0 is NotificationsPermission } as? NotificationsPermission
            let notificationsPermissionSet = notificationsPermission?.notificationCategories

            NotificationCenter.default.addObserver(self, selector: #selector(showingNotificationPermission), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
            
            notificationTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(finishedShowingNotificationPermission), userInfo: nil, repeats: false)
            
            UIApplication.shared.registerUserNotificationSettings(
                UIUserNotificationSettings(types: [.alert, .sound, .badge],
                categories: notificationsPermissionSet)
            )
        case .unauthorized:
            showDeniedAlert(.notifications)
        case .disabled:
            showDisabledAlert(.notifications)
        case .authorized:
            detectAndCallback()
        }
    }
    
    // MARK: Camera
    
    /**
    Returns the current permission status for accessing the Camera.
    
    - returns: Permission status for the requested type.
    */
    public func statusCamera() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch status {
        case .authorized:
            return .authorized
        case .restricted, .denied:
            return .unauthorized
        case .notDetermined:
            return .unknown
        }
    }
    
    /**
    Requests access to the Camera, if necessary.
    */
    public func requestCamera() {
        let status = statusCamera()
        switch status {
        case .unknown:
            AVCaptureDevice.requestAccess(for: AVMediaType.video,
                completionHandler: { granted in
                    self.detectAndCallback()
            })
        case .unauthorized:
            showDeniedAlert(.camera)
        case .disabled:
            showDisabledAlert(.camera)
        case .authorized:
            break
        }
    }

    // MARK: Photos
    
    /**
    Returns the current permission status for accessing Photos.
    
    - returns: Permission status for the requested type.
    */
    public func statusPhotos() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .unauthorized
        case .notDetermined:
            return .unknown
        }
    }
    
    /**
    Requests access to Photos, if necessary.
    */
    public func requestPhotos() {
        let status = statusPhotos()
        switch status {
        case .unknown:
            PHPhotoLibrary.requestAuthorization({ status in
                self.detectAndCallback()
            })
        case .unauthorized:
            self.showDeniedAlert(.photos)
        case .disabled:
            showDisabledAlert(.photos)
        case .authorized:
            break
        }
    }

    // MARK: - UI
    
    /**
    Shows the modal viewcontroller for requesting access to the configured permissions and sets up the closures on it.
    
    - parameter authChange: Called when a status is detected on any of the permissions.
    - parameter cancelled:  Called when the user taps the Close button.
    */
    @objc public func show(_ authChange: authClosureType? = nil, cancelled: cancelClosureType? = nil) {
        assert(!configuredPermissions.isEmpty, "Please add at least one permission")

        onAuthChange = authChange
        onCancel = cancelled
        
        DispatchQueue.main.async {
            // call other methods that need to wait before show
            // no missing required perms? callback and do nothing
            self.requiredAuthorized({ areAuthorized in
                if areAuthorized {
                    self.getResultsForConfig({ results in

                        self.onAuthChange?(true, results)
                    })
                } else {
                    self.showAlert()
                }
            })
        }
    }
    
    /**
    Creates the modal viewcontroller and shows it.
    */
    fileprivate func showAlert() {
        // add the backing views
        let window = UIApplication.shared.keyWindow!
        
        //hide KB if it is shown
        window.endEditing(true)
        
        window.addSubview(view)
        view.frame = window.bounds
        baseView.frame = window.bounds

        for button in permissionButtons {
            button.removeFromSuperview()
        }
        permissionButtons = []

        for label in permissionLabels {
            label.removeFromSuperview()
        }
        permissionLabels = []

        // create the buttons
        for permission in configuredPermissions {
            let button = permissionStyledButton(permission.type)
            permissionButtons.append(button)
            contentView.addSubview(button)

            let label = permissionStyledLabel(permission.type)
            permissionLabels.append(label)
            contentView.addSubview(label)
        }
        
        self.view.setNeedsLayout()
        
        // slide in the view
        self.baseView.frame.origin.y = self.view.bounds.origin.y - self.baseView.frame.size.height
        self.view.alpha = 0
        
        UIView.animate(withDuration: 0.2, delay: 0.0, options: [], animations: {
            self.baseView.center.y = window.center.y + 15
            self.view.alpha = 1
        }, completion: { finished in
            UIView.animate(withDuration: 0.2, animations: {
                self.baseView.center = window.center
            })
        })
    }

    /**
    Hides the modal viewcontroller with an animation.
    */
    public func hide() {
        let window = UIApplication.shared.keyWindow!

        DispatchQueue.main.async(execute: {
            UIView.animate(withDuration: 0.2, animations: {
                self.baseView.frame.origin.y = window.center.y + 400
                self.view.alpha = 0
            }, completion: { finished in
                self.view.removeFromSuperview()
            })
        })
        
        notificationTimer?.invalidate()
        notificationTimer = nil
    }
    
    // MARK: - Delegates
    
    // MARK: Gesture delegate
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // this prevents our tap gesture from firing for subviews of baseview
        if touch.view == baseView {
            return true
        }
        return false
    }

    // MARK: - UI Helpers
    
    /**
    Called when the users taps on the close button.
    */
    @objc func cancel() {
        self.hide()
        
        if let onCancel = onCancel {
            getResultsForConfig({ results in
                onCancel(results)
            })
        }
    }
    
    /**
    Shows an alert for a permission which was Denied.
    
    - parameter permission: Permission type.
    */
    func showDeniedAlert(_ permission: PermissionType) {
        // compile the results and pass them back if necessary
        if let onDisabledOrDenied = self.onDisabledOrDenied {
            self.getResultsForConfig({ results in
                onDisabledOrDenied(results)
            })
        }
        
        let alert = UIAlertController(title: "Permission for \(permission.prettyDescription) was denied.".localized,
            message: "Please enable access to \(permission.prettyDescription) in the Settings app".localized,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized,
            style: .cancel,
            handler: nil))
        alert.addAction(UIAlertAction(title: "Show me".localized,
            style: .default,
            handler: { action in
                NotificationCenter.default.addObserver(self, selector: #selector(self.appForegroundedAfterSettings), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
                
                let settingsUrl = URL(string: UIApplicationOpenSettingsURLString)
                UIApplication.shared.openURL(settingsUrl!)
        }))
        
        DispatchQueue.main.async {
            self.viewControllerForAlerts?.present(alert,
                animated: true, completion: nil)
        }
    }
    
    /**
    Shows an alert for a permission which was Disabled (system-wide).
    
    - parameter permission: Permission type.
    */
    func showDisabledAlert(_ permission: PermissionType) {
        // compile the results and pass them back if necessary
        if let onDisabledOrDenied = self.onDisabledOrDenied {
            self.getResultsForConfig({ results in
                onDisabledOrDenied(results)
            })
        }
        
        let alert = UIAlertController(title: "\(permission.prettyDescription) is currently disabled.".localized,
            message: "Please enable access to \(permission.prettyDescription) in Settings".localized,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized,
            style: .cancel,
            handler: nil))
        alert.addAction(UIAlertAction(title: "Show me".localized,
            style: .default,
            handler: { action in
                NotificationCenter.default.addObserver(self, selector: #selector(self.appForegroundedAfterSettings), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
                
                let settingsUrl = URL(string: UIApplicationOpenSettingsURLString)
                UIApplication.shared.openURL(settingsUrl!)
        }))
        
        DispatchQueue.main.async {
            self.viewControllerForAlerts?.present(alert,
                animated: true, completion: nil)
        }
    }

    // MARK: Helpers
    
    /**
    This notification callback is triggered when the app comes back
    from the settings page, after a user has tapped the "show me" 
    button to check on a disabled permission. It calls detectAndCallback
    to recheck all the permissions and update the UI.
    */
    @objc func appForegroundedAfterSettings() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        detectAndCallback()
    }
    
    /**
    Requests the status of any permission.
    
    - parameter type:       Permission type to be requested
    - parameter completion: Closure called when the request is done.
    */
    func statusForPermission(_ type: PermissionType, completion: statusRequestClosure) {
        // Get permission status
        let permissionStatus: PermissionStatus
        switch type {
        case .contacts:
            permissionStatus = statusContacts()
        case .notifications:
            permissionStatus = statusNotifications()
        case .camera:
            permissionStatus = statusCamera()
        case .photos:
            permissionStatus = statusPhotos()
        }
        
        // Perform completion
        completion(permissionStatus)
    }
    
    /**
    Rechecks the status of each requested permission, updates
    the PermissionScope UI in response and calls your onAuthChange
    to notifiy the parent app.
    */
    func detectAndCallback() {
        DispatchQueue.main.async {
            // compile the results and pass them back if necessary
            if let onAuthChange = self.onAuthChange {
                self.getResultsForConfig({ results in
                    self.allAuthorized({ areAuthorized in
                        onAuthChange(areAuthorized, results)
                    })
                })
            }
            
            self.view.setNeedsLayout()

            // and hide if we've sucessfully got all permissions
            self.allAuthorized({ areAuthorized in
                if areAuthorized {
                    self.hide()
                }
            })
        }
    }
    
    /**
    Calculates the status for each configured permissions for the caller
    */
    func getResultsForConfig(_ completionBlock: resultsForConfigClosure) {
        var results: [PermissionResult] = []
        
        for config in configuredPermissions {
            self.statusForPermission(config.type, completion: { status in
                let result = PermissionResult(type: config.type,
                    status: status)
                results.append(result)
            })
        }
        
        completionBlock(results)
    }
}
