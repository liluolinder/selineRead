package ignite

public type Handler = (Ctx) -> Unit

public type ErrorHandler = (Ctx, Exception) -> Unit

public type KModePanicHandler = (Ctx, Exception) -> Bool
