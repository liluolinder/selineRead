macro package CJson.jsonmacro

class AdaptorMissingException <: Exception {
    public init(message: String) {
        super(message)
    }
}

class TypeInferrenceException <: Exception {
    public init(message: String) {
        super(message)
    }
}

class TokenVerificationException <: Exception {
    public init(message: String) {
        super(message)
    }
}

class MacroExpansionException <: Exception {
    public init(message: String) {
        super(message)
    }
}

class MacroParameterException <: Exception {
    public init(message: String) {
        super(message)
    }
}
