//
//  Structs.swift
//  PermissionScope
//
//  Created by Nick O'Neill on 8/21/15.
//  Copyright © 2015 That Thing in Swift. All rights reserved.
//

import Foundation

/// Permissions currently supportes by PermissionScope
@objc public enum PermissionType: Int, CustomStringConvertible {
    case contacts, notifications, microphone, camera, photos, reminders, events, motion
    
    public var prettyDescription: String {
        return "\(self)"
    }
    
    public var description: String {
        switch self {
        case .contacts:         return "Contacts"
        case .events:           return "Events"
        case .notifications:    return "Notifications"
        case .microphone:       return "Microphone"
        case .camera:           return "Camera"
        case .photos:           return "Photos"
        case .reminders:        return "Reminders"
        case .motion:           return "Motion"
        }
    }
    
    static let allValues = [contacts, notifications, microphone, camera, photos, reminders, events, motion]
}

/// Possible statuses for a permission.
@objc public enum PermissionStatus: Int, CustomStringConvertible {
    case authorized, unauthorized, unknown, disabled
    
    public var description: String {
        switch self {
        case .authorized:   return "Authorized"
        case .unauthorized: return "Unauthorized"
        case .unknown:      return "Unknown"
        case .disabled:     return "Disabled" // System-level
        }
    }
}

/// Result for a permission status request.
@objc public class PermissionResult: NSObject {
    public let type: PermissionType
    public let status: PermissionStatus
    
    internal init(type:PermissionType, status:PermissionStatus) {
        self.type   = type
        self.status = status
    }
    
    override public var description: String {
        return "\(type) \(status)"
    }
}
