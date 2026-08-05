/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

public class UncheckedIOException <: Exception {
    init(cause: IOException) {
        super(cause.message)
    }

    init(message: String) {
        super(message)
    }

    public override func toString(): String {
        "UncheckedIOException: ${this.message}"
    }
}

/*
 * A SerializationException is raised whenever serialization of a DOM element fails.
 */
public class SerializationException <: Exception {
    /*
     * Creates and initializes a new serialization exception with no error message and cause.
     */
    init() {
        super()
    }

    /*
     * Creates and initializes a new serialization exception with the given error message and no cause.
     *
     * @param message the error message of the new serialization exception (may be null).
     */
    init(message: String) {
        super(message)
    }

    /*
     * Creates and initializes a new serialization exception with the specified cause and an error message of
     *
     * @param cause the cause of the new serialization exception (may be <code>null</code>).
     */
    init(cause: Exception) {
        super(cause.message)
    }

    /*
     * Creates and initializes a new serialization exception with the given error message and cause.
     *
     * @param message the error message of the new serialization exception.
     * @param cause the cause of the new serialization exception.
     */
    init(message: String, cause: Exception) {
        super("${message} : ${cause.message}")
    }

    public override func toString(): String {
        "SerializationException: ${this.message}"
    }
}

/*
 * Validation exceptions, as thrown by the methods in Validate.
 */
public class ValidationException <: Exception {
    init(message: String) {
        super(message)
    }

    public override func toString(): String {
        "ValidationException: ${this.message}"
    }
}

public class SelectorParseException <: Exception {
    init(msg: String) {
        super(msg)
    }

    public override func toString(): String {
        "SelectorParseException: ${this.message}"
    }
}

public class ParseException <: Exception {
    init(msg: String) {
        super(msg)
    }

    public override func toString(): String {
        "ParseException: ${this.message}"
    }
}

public class IllegalStateException <: Exception {
    init(msg: String) {
        super(msg)
    }

    public override func toString(): String {
        "IllegalStateException: ${this.message}"
    }
}
