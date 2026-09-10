package chui.system

import std.collection.ArrayList

/** A native-menu-safe group of stable application actions. */
public struct AppMenu {
    public let id: String
    public let title: String
    public let actionIds: Array<String>

    public init(id: String, title: String, actionIds!: Array<String> = []) {
        validateDottedIdentifier(id, "application menu")
        if (title.isEmpty()) {
            throw IllegalArgumentException("application menu title must not be empty")
        }
        for (actionId in actionIds) {
            validateAppActionId(actionId)
        }
        this.id = id
        this.title = title
        this.actionIds = actionIds
    }
}

/** Declarative application menu projection shared by native and headless hosts. */
public struct AppMenuBar {
    public let menus: Array<AppMenu>

    public init(menus!: Array<AppMenu> = []) {
        for (i in 0..menus.size) {
            for (j in (i + 1)..menus.size) {
                if (menus[i].id == menus[j].id) {
                    throw IllegalArgumentException("duplicate application menu: " + menus[i].id)
                }
            }
        }
        this.menus = menus
    }
}

/** Results for the two application-owned system surfaces projected together. */
public struct AppSurfaceProjectionResult {
    public let applicationMenu: SystemShellResult
    public let statusItem: SystemShellResult

    public init(applicationMenu: SystemShellResult, statusItem: SystemShellResult) {
        this.applicationMenu = applicationMenu
        this.statusItem = statusItem
    }

    public func ok(): Bool {
        applicationMenu.ok() && statusItem.ok()
    }
}

func validateMenuActionReferences(menu: AppMenuBar, actions: Array<AppAction>, errors: ArrayList<String>): Unit {
    for (entry in menu.menus) {
        validateReferencedActions(entry.actionIds, actions, "menu " + entry.id, errors)
    }
}

func validateStatusActionReferences(item: AppStatusItem, actions: Array<AppAction>, errors: ArrayList<String>): Unit {
    validateReferencedActions(item.actionIds, actions, "status item", errors)
}

func validateReferencedActions(actionIds: Array<String>, actions: Array<AppAction>, surface: String,
    errors: ArrayList<String>): Unit {
    for (i in 0..actionIds.size) {
        if (!containsAction(actions, actionIds[i])) {
            errors.add(surface + " references unknown action: " + actionIds[i])
        }
        for (j in (i + 1)..actionIds.size) {
            if (actionIds[i] == actionIds[j]) {
                errors.add(surface + " references duplicate action: " + actionIds[i])
            }
        }
    }
}
