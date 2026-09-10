package sdl

import std.collection.ArrayList

private class OpenedGamepad {
    let id: UInt32
    let handle: CPointer<Unit>
    var name: String

    init(id: UInt32, handle: CPointer<Unit>, name: String) {
        this.id = id
        this.handle = handle
        this.name = name
    }
}

/** Owns SDL gamepad handles while keeping SDL identities out of public events. */
internal class GamepadRuntime {
    private let opened = ArrayList<OpenedGamepad>()
    private let enabled: Bool

    init() {
        enabled = unsafe { SDL_InitSubSystem(SDL_INIT_GAMEPAD) }
    }

    func enrich(event: UiEvent): UiEvent {
        match (event) {
            case UiEvent.GamepadConnectionChanged(device, GamepadConnectionState.Connected) => open(device.id)
            case UiEvent.GamepadConnectionChanged(device, GamepadConnectionState.Disconnected) => remove(device.id)
            case UiEvent.GamepadConnectionChanged(device, GamepadConnectionState.Remapped) => remap(device.id)
            case _ => event
        }
    }

    func close(): Unit {
        var i: Int64 = opened.size - 1
        while (i >= 0) {
            let item = opened.remove(at: i)
            unsafe { SDL_CloseGamepad(item.handle) }
            i -= 1
        }
        if (enabled) {
            unsafe { SDL_QuitSubSystem(SDL_INIT_GAMEPAD) }
        }
    }

    private func open(id: UInt32): UiEvent {
        if (!enabled) {
            return UiEvent.GamepadConnectionChanged(GamepadDevice(id),
                GamepadConnectionState.Unavailable("SDL gamepad subsystem is unavailable"))
        }
        match (find(id)) {
            case Some(index) =>
                let current = opened[index]
                return UiEvent.GamepadConnectionChanged(GamepadDevice(id, name: current.name),
                    GamepadConnectionState.Connected)
            case None => ()
        }
        let handle = unsafe { SDL_OpenGamepad(id) }
        if (handle.isNull()) {
            return UiEvent.GamepadConnectionChanged(GamepadDevice(id),
                GamepadConnectionState.Unavailable(lastSdlError()))
        }
        let name = gamepadName(handle)
        opened.add(OpenedGamepad(id, handle, name))
        UiEvent.GamepadConnectionChanged(GamepadDevice(id, name: name), GamepadConnectionState.Connected)
    }

    private func remove(id: UInt32): UiEvent {
        match (find(id)) {
            case Some(index) =>
                let item = opened.remove(at: index)
                unsafe { SDL_CloseGamepad(item.handle) }
                UiEvent.GamepadConnectionChanged(GamepadDevice(id, name: item.name),
                    GamepadConnectionState.Disconnected)
            case None => UiEvent.GamepadConnectionChanged(GamepadDevice(id), GamepadConnectionState.Disconnected)
        }
    }

    private func remap(id: UInt32): UiEvent {
        match (find(id)) {
            case Some(index) =>
                let item = opened[index]
                item.name = gamepadName(item.handle)
                UiEvent.GamepadConnectionChanged(GamepadDevice(id, name: item.name),
                    GamepadConnectionState.Remapped)
            case None =>
                match (open(id)) {
                    case UiEvent.GamepadConnectionChanged(device, GamepadConnectionState.Connected) =>
                        UiEvent.GamepadConnectionChanged(device, GamepadConnectionState.Remapped)
                    case unavailable => unavailable
                }
        }
    }

    private func find(id: UInt32): ?Int64 {
        var i: Int64 = 0
        while (i < opened.size) {
            if (opened[i].id == id) { return Some(i) }
            i += 1
        }
        None
    }
}

private func gamepadName(handle: CPointer<Unit>): String {
    let raw = unsafe { SDL_GetGamepadName(handle) }
    if (raw.isNull()) { "" } else { raw.toString() }
}
