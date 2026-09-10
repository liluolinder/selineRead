package chui.system

import std.collection.ArrayList

public enum NotificationPermissionState <: Equatable<NotificationPermissionState> {
    | NotDetermined
    | Granted
    | Denied
    | NotRequired
    | Unsupported

    public operator func ==(other: NotificationPermissionState): Bool {
        notificationPermissionStateName(this) == notificationPermissionStateName(other)
    }

    public operator func !=(other: NotificationPermissionState): Bool {
        !(this == other)
    }
}

public func notificationPermissionStateName(state: NotificationPermissionState): String {
    match (state) {
        case NotificationPermissionState.NotDetermined => "not-determined"
        case NotificationPermissionState.Granted => "granted"
        case NotificationPermissionState.Denied => "denied"
        case NotificationPermissionState.NotRequired => "not-required"
        case NotificationPermissionState.Unsupported => "unsupported"
    }
}

/** Exact deep-link route. Prefix and wildcard matching are intentionally excluded. */
public struct AppDeepLinkRoute {
    public let uri: String
    public let actionId: String

    public init(uri: String, actionId: String) {
        validateAppDeepLinkUri(uri)
        validateAppActionId(actionId)
        this.uri = uri
        this.actionId = actionId
    }
}

public func validateAppDeepLinkUri(uri: String): Unit {
    let runes = uri.toRuneArray()
    if (runes.size < 6) {
        throw IllegalArgumentException("application deep link must contain scheme://target")
    }
    var separator: Int64 = -1
    for (i in 0..runes.size) {
        let rune = runes[i]
        if (rune == r' ' || rune == r'\t' || rune == r'\n' || rune == r'\r') {
            throw IllegalArgumentException("application deep link must not contain whitespace")
        }
        if (rune == r':' && separator < 0) { separator = i }
    }
    if (separator <= 0 || separator + 3 >= runes.size ||
        runes[separator + 1] != r'/' || runes[separator + 2] != r'/') {
        throw IllegalArgumentException("application deep link must contain scheme://target")
    }
    for (i in 0..separator) {
        let rune = runes[i]
        let letter = (rune >= r'a' && rune <= r'z') || (rune >= r'A' && rune <= r'Z')
        let digit = rune >= r'0' && rune <= r'9'
        if ((!letter && !digit && rune != r'+' && rune != r'-' && rune != r'.') ||
            (i == 0 && !letter)) {
            throw IllegalArgumentException("invalid application deep-link scheme: " + uri)
        }
    }
}

func validateDeepLinkRoutes(routes: Array<AppDeepLinkRoute>, actions: Array<AppAction>,
    errors: ArrayList<String>): Unit {
    for (i in 0..routes.size) {
        if (!containsAction(actions, routes[i].actionId)) {
            errors.add("deep link references unknown action: " + routes[i].actionId)
        }
        for (j in (i + 1)..routes.size) {
            if (routes[i].uri == routes[j].uri) {
                errors.add("duplicate application deep link: " + routes[i].uri)
            }
        }
    }
}
