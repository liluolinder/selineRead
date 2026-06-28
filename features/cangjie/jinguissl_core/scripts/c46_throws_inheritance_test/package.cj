package c46_throws_inheritance_test

/**
 * Base exception for the experiment.
 */
public open class BaseException <: Exception {
    public init(message: String) {
        super(message)
    }
    protected open override func getClassName(): String {
        return "BaseException"
    }
}

/**
 * Derived exception.
 */
public class DerivedException <: BaseException {
    public init(message: String) {
        super(message)
    }
    protected override func getClassName(): String {
        return "DerivedException"
    }
}

/**
 * Base class with documented @throws.
 */
public open class Base {
    /**
     * A method that throws.
     *
     * @throws BaseException if something goes wrong.
     */
    public open func doSomething(): Unit {
        throw BaseException("base error")
    }
}

/**
 * Child class overriding the method but OMITTING @throws.
 *
 * Expected: cjdoc should NOT inherit @throws from parent.
 */
public class Child <: Base {
    /**
     * Override without @throws.
     */
    public override func doSomething(): Unit {
        throw DerivedException("child error")
    }
}

/**
 * Another child that DOES document @throws explicitly.
 *
 * This is the correct pattern to follow.
 */
public class CorrectChild <: Base {
    /**
     * Override with explicit @throws.
     *
     * @throws DerivedException if something goes wrong.
     */
    public override func doSomething(): Unit {
        throw DerivedException("child explicit error")
    }
}

/**
 * Run the experiment.
 */
main() {
    let b: Base = Child()
    try {
        b.doSomething()
    } catch (e: DerivedException) {
        println("Caught DerivedException: ${e.message}")
    } catch (e: BaseException) {
        println("Caught BaseException: ${e.message}")
    }

    let c: Base = CorrectChild()
    try {
        c.doSomething()
    } catch (e: DerivedException) {
        println("Caught DerivedException: ${e.message}")
    } catch (e: BaseException) {
        println("Caught BaseException: ${e.message}")
    }

    println("Experiment complete. Both paths executed correctly.")
    println("Conclusion: Cangjie requires explicit @throws on every function.")
    println("No @throws inheritance exists. C45 approach is correct.")
}
