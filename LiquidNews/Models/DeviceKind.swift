// DeviceKind.swift
// Coarse device classification used to label where a synced resume entry came
// from ("On iPad"). Derived from the UI idiom only — no entitlement, no prompt.

import UIKit

enum DeviceKind: String, Codable {
    case phone, pad, mac, other

    var label: String {
        switch self {
        case .phone: return "iPhone"
        case .pad:   return "iPad"
        case .mac:   return "Mac"
        case .other: return "another device"
        }
    }

    var symbol: String {
        switch self {
        case .phone: return "iphone"
        case .pad:   return "ipad"
        case .mac:   return "laptopcomputer"
        case .other: return "rectangle.on.rectangle"
        }
    }

    init(idiom: UIUserInterfaceIdiom) {
        switch idiom {
        case .phone: self = .phone
        case .pad:   self = .pad
        case .mac:   self = .mac
        default:     self = .other
        }
    }

    static var current: DeviceKind {
        DeviceKind(idiom: UIDevice.current.userInterfaceIdiom)
    }
}
