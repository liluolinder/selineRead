/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Validators to check that method arguments meet expectations.
 */
class Validate {
    private Validate() {}

    /*
     * Validates that the object is not null
     *
     * @param obj Any to test
     */
    public static func notNull<T>(obj: ?T): Unit {
        obj.getOrThrow {=> ValidationException("Object must not be null")}
    }

    /*
     * Validates that the parameter is not null
     *
     * @param obj the parameter to test
     * @param param the name of the parameter, for presentation in the validation exception.
     */
    public static func notNullParam<T>(obj: ?T, param: String): Unit {
        obj.getOrThrow {=> ValidationException("The parameter '${param}' must not be null.")}
    }

    /*
     * Validates that the object is not null
     *
     * @param obj the parameter to test
     * @param param the name of the parameter, for presentation in the validation exception.
     */
    public static func notNull<T>(obj: ?T, msg: String): Unit {
        obj.getOrThrow {=> ValidationException(msg)}
    }

    /*
     * Verifies the input object is not null, and returns that object.
     *
     * @param obj nullable object to case to not-null
     * @return the object, or throws an exception if it is null
     */
    public static func ensureNotNull<T>(obj: ?T): T {
        obj.getOrThrow {=> ValidationException("Object must not be null")}
    }

    /*
     * Verifies the input object is not null, and returns that object.
     *
     * @param obj nullable object to case to not-null
     * @param msg the String format message to include in the validation exception when thrown
     * @param args the arguments to the msg
     * @return the object, or throws an exception if it is null
     */
    public static func ensureNotNull<T>(obj: ?T, msg: String): T {
        obj.getOrThrow {=> ValidationException(msg)}
    }

    /*
     * Validates that the value is true
     *
     * @param valBool object to test
     */
    public static func isTrue(valBool: Bool): Unit {
        if (!valBool) {
            throw ValidationException("Must be true")
        }
    }

    /*
     * Validates that the value is true
     *
     * @param valBool object to test
     * @param msg message to include in the Exception if validation fails
     */
    public static func isTrue(valBool: Bool, msg: String): Unit {
        if (!valBool) {
            throw ValidationException(msg)
        }
    }

    /*
     * Validates that the value is false
     *
     * @param valBool object to test
     */
    public static func isFalse(valBool: Bool): Unit {
        if (valBool) {
            throw ValidationException("Must be false")
        }
    }

    /*
     * Validates that the value is false
     *
     * @param valBool object to test
     * @param msg message to include in the Exception if validation fails
     */
    public static func isFalse(valBool: Bool, msg: String): Unit {
        if (valBool) {
            throw ValidationException(msg)
        }
    }

    /*
     * Validates that the array contains no null elements
     *
     * @param objects the array to test
     */
    public static func noNullElements(objects: Array<?Object>): Unit {
        noNullElements(objects, "Array must not contain any null objects")
    }

    /*
     * Validates that the array contains no null elements
     *
     * @param objects the array to test
     * @param msg message to include in the Exception if validation fails
     */
    public static func noNullElements(objects: Array<?Object>, msg: String): Unit {
        for (obj in objects) {
            obj.getOrThrow {=> ValidationException(msg)}
        }
    }

    /*
     * Validates that the string is not null and is not empty
     *
     * @param string the string to test
     */
    public static func notEmpty(string: ?String): Unit {
        match (string) {
            case None => throw ValidationException("String must not be empty")
            case Some(v) where v.size == 0 => throw ValidationException("String must not be empty")
            case _ => ()
        }
    }

    /*
     * Validates that the string parameter is not null and is not empty
     *
     * @param string the string to test
     * @param param the name of the parameter, for presentation in the validation exception.
     */
    public static func notEmptyParam(string: ?String, param: String): Unit {
        match (string) {
            case None => throw ValidationException("The '${param}' parameter must not be empty.")
            case Some(v) where v.size == 0 => throw ValidationException("The '${param}' parameter must not be empty.")
            case _ => ()
        }
    }

    /*
     * Validates that the string is not null and is not empty
     *
     * @param string the string to test
     * @param msg message to include in the Exception if validation fails
     */
    public static func notEmpty(string: ?String, msg: String): Unit {
        match (string) {
            case None => throw ValidationException(msg)
            case Some(v) where v.size == 0 => throw ValidationException(msg)
            case _ => ()
        }
    }

    /*
     * Blow up if we reach an unexpected state.
     *
     * @param msg message to think about
     */
    public static func wtf(msg: String): Unit {
        throw IllegalStateException(msg)
    }

    /*
     * Cause a failure.
     *
     * @param msg message to output.
     */
    public static func fail(msg: String): Unit {
        throw ValidationException(msg)
    }
}
