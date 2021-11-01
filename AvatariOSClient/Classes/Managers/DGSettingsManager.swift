//
//  DGSettingsManager.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 9/21/20.
//

import UIKit

@objc protocol DGSettingsManagerAbstract {
    var userName: String { get set }
    var password: String { get set }
    var url: URL? { get set }

    @objc optional func save()
}

fileprivate let __defaultUrlString: String = "amqp://idl:idlpwd@192.168.0.26:5672"

class DGSettingsManager : DGSettingsManagerAbstract {


    private let _userNameKey = "rmqUserName"
    private let _passwordKey = "rmqPassword"
    private let _urlKey = "rqmUrl"

    var userName: String {
        get {
            return _userDefaults.string(forKey: _userNameKey) ?? "idl"
        }
        set {
            _userDefaults.setValue(newValue, forKey: _userNameKey)

            // Update url
            let url: URL? = _userDefaults.value(forKey: _urlKey) as? URL

            var components = URLComponents()
            components.scheme = url?.scheme ?? "amqp" 
            components.user = newValue
            components.password = password
            components.host = url?.host ?? "gpu-08.indatalabs.com"
            components.port = url?.port ?? 5672
            components.path = url?.path ?? ""

            guard let newUrl = components.url else {
                return
            }

            _userDefaults.setValue(newUrl.absoluteString, forKey: _urlKey)
        }
    }

    var password: String {
        get {
            return _userDefaults.string(forKey: _passwordKey) ?? "idlpwd"
        }
        set {
            _userDefaults.setValue(newValue, forKey: _passwordKey)

            var components = URLComponents()
            components.scheme = url?.scheme ?? "amqp"
            components.user = userName
            components.password = newValue
            components.host = url?.host ?? "gpu-08.indatalabs.com"
            components.port = url?.port ?? 5672
            components.path = url?.path ?? ""

            guard let newUrl = components.url else {
                return
            }

            _userDefaults.setValue(newUrl.absoluteString, forKey: _urlKey)

        }
    }

    var url: URL? {
        get {
            let string = _userDefaults.value(forKey: _urlKey) as? String ?? __defaultUrlString
            return URL(string: string)
        }
        set {
            _userDefaults.set(newValue?.absoluteString, forKey: _urlKey)
        }
    }

    static let shared = DGSettingsManager()
    var _userDefaults: UserDefaults

    private init() {
        _userDefaults = UserDefaults.standard
    }

    func save() {
        // Empty implementation
    }
}
