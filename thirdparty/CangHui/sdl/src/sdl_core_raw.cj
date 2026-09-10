package sdl

foreign {
    func SDL_Init(flags: UInt32): Bool

    func SDL_InitSubSystem(flags: UInt32): Bool

    func SDL_QuitSubSystem(flags: UInt32): Unit

    func SDL_Quit(): Unit

    func SDL_GetError(): CString

    func SDL_GetVersion(): Int32

    func SDL_GetRevision(): CString

    func SDL_PollEvent(event: CPointer<SdlEvent>): Bool

    func SDL_GetTicks(): UInt64

    func SDL_Delay(ms: UInt32): Unit

    func SDL_GetCurrentThreadID(): UInt64

    func SDL_OpenGamepad(instanceId: UInt32): CPointer<Unit>

    func SDL_GetGamepadName(gamepad: CPointer<Unit>): CString

    func SDL_CloseGamepad(gamepad: CPointer<Unit>): Unit
}
