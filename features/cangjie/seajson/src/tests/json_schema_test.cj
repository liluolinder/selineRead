package seajson.tests

import seajson.*
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

// ── JSON Schema validation tests ─────────────────────────────────────

@Test
public class JsonSchemaTestSuite {

    // ── Type validation tests ──────────────────────────────────────────

    @TestCase
    public func testValidateString(): Unit {
        let value = parseJson("\"hello\"")
        let schema = parseJson("{\"type\":\"string\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testValidateStringFail(): Unit {
        let value = parseJson("42")
        let schema = parseJson("{\"type\":\"string\"}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testValidateInteger(): Unit {
        let value = parseJson("42")
        let schema = parseJson("{\"type\":\"integer\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testValidateIntegerFail(): Unit {
        let value = parseJson("3.14")
        let schema = parseJson("{\"type\":\"integer\"}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testValidateNumber(): Unit {
        let value = parseJson("3.14")
        let schema = parseJson("{\"type\":\"number\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testValidateNumberIntIsNumber(): Unit {
        let value = parseJson("42")
        let schema = parseJson("{\"type\":\"number\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testValidateBoolean(): Unit {
        let value = parseJson("true")
        let schema = parseJson("{\"type\":\"boolean\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testValidateBooleanFail(): Unit {
        let value = parseJson("\"true\"")
        let schema = parseJson("{\"type\":\"boolean\"}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testValidateObject(): Unit {
        let value = parseJson("{\"name\":\"test\"}")
        let schema = parseJson("{\"type\":\"object\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testValidateArray(): Unit {
        let value = parseJson("[1,2,3]")
        let schema = parseJson("{\"type\":\"array\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testValidateNull(): Unit {
        let value = parseJson("null")
        let schema = parseJson("{\"type\":\"null\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    // ── String constraints tests ───────────────────────────────────────

    @TestCase
    public func testMinLength(): Unit {
        let value = parseJson("\"hello\"")
        let schema = parseJson("{\"type\":\"string\",\"minLength\":3}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testMinLengthFail(): Unit {
        let value = parseJson("\"hi\"")
        let schema = parseJson("{\"type\":\"string\",\"minLength\":3}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testMaxLength(): Unit {
        let value = parseJson("\"hello\"")
        let schema = parseJson("{\"type\":\"string\",\"maxLength\":10}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testMaxLengthFail(): Unit {
        let value = parseJson("\"hello world\"")
        let schema = parseJson("{\"type\":\"string\",\"maxLength\":5}")
        @Assert(isValidSchema(value, schema), false)
    }

    // ── Number constraints tests ────────────────────────────────────────

    @TestCase
    public func testMinimum(): Unit {
        let value = parseJson("10")
        let schema = parseJson("{\"type\":\"integer\",\"minimum\":5}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testMinimumFail(): Unit {
        let value = parseJson("3")
        let schema = parseJson("{\"type\":\"integer\",\"minimum\":5}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testMaximum(): Unit {
        let value = parseJson("10")
        let schema = parseJson("{\"type\":\"integer\",\"maximum\":15}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testMaximumFail(): Unit {
        let value = parseJson("20")
        let schema = parseJson("{\"type\":\"integer\",\"maximum\":15}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testExclusiveMinimum(): Unit {
        let value = parseJson("6")
        let schema = parseJson("{\"type\":\"integer\",\"exclusiveMinimum\":5}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testExclusiveMinimumFail(): Unit {
        let value = parseJson("5")
        let schema = parseJson("{\"type\":\"integer\",\"exclusiveMinimum\":5}")
        @Assert(isValidSchema(value, schema), false)
    }

    // ── Object constraints tests ────────────────────────────────────────

    @TestCase
    public func testRequiredFields(): Unit {
        let value = parseJson("{\"name\":\"Alice\",\"age\":30}")
        let schema = parseJson("{\"type\":\"object\",\"required\":[\"name\",\"age\"]}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testRequiredFieldsMissing(): Unit {
        let value = parseJson("{\"name\":\"Alice\"}")
        let schema = parseJson("{\"type\":\"object\",\"required\":[\"name\",\"age\"]}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testPropertiesValidation(): Unit {
        let value = parseJson("{\"name\":\"Alice\",\"age\":30}")
        let schema = parseJson("{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"age\":{\"type\":\"integer\",\"minimum\":0}}}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testPropertiesValidationNestedFail(): Unit {
        let value = parseJson("{\"name\":\"Alice\",\"age\":-5}")
        let schema = parseJson("{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"age\":{\"type\":\"integer\",\"minimum\":0}}}")
        @Assert(isValidSchema(value, schema), false)
    }

    // ── Array constraints tests ─────────────────────────────────────────

    @TestCase
    public func testMinItems(): Unit {
        let value = parseJson("[1,2,3]")
        let schema = parseJson("{\"type\":\"array\",\"minItems\":2}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testMinItemsFail(): Unit {
        let value = parseJson("[1]")
        let schema = parseJson("{\"type\":\"array\",\"minItems\":2}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testMaxItems(): Unit {
        let value = parseJson("[1,2]")
        let schema = parseJson("{\"type\":\"array\",\"maxItems\":3}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testMaxItemsFail(): Unit {
        let value = parseJson("[1,2,3,4]")
        let schema = parseJson("{\"type\":\"array\",\"maxItems\":3}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testItemsSchema(): Unit {
        let value = parseJson("[1,2,3]")
        let schema = parseJson("{\"type\":\"array\",\"items\":{\"type\":\"integer\"}}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testItemsSchemaFail(): Unit {
        let value = parseJson("[1,\"two\",3]")
        let schema = parseJson("{\"type\":\"array\",\"items\":{\"type\":\"integer\"}}")
        @Assert(isValidSchema(value, schema), false)
    }

    // ── Enum and const tests ────────────────────────────────────────────

    @TestCase
    public func testEnumValid(): Unit {
        let value = parseJson("\"red\"")
        let schema = parseJson("{\"enum\":[\"red\",\"green\",\"blue\"]}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testEnumInvalid(): Unit {
        let value = parseJson("\"yellow\"")
        let schema = parseJson("{\"enum\":[\"red\",\"green\",\"blue\"]}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testConstValid(): Unit {
        let value = parseJson("\"fixed\"")
        let schema = parseJson("{\"const\":\"fixed\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testConstInvalid(): Unit {
        let value = parseJson("\"other\"")
        let schema = parseJson("{\"const\":\"fixed\"}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testConstNumber(): Unit {
        let value = parseJson("42")
        let schema = parseJson("{\"const\":42}")
        @Assert(isValidSchema(value, schema), true)
    }

    // ── Boolean schema tests ────────────────────────────────────────────

    @TestCase
    public func testTrueSchema(): Unit {
        let value = parseJson("42")
        let schema = parseJson("true")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testFalseSchema(): Unit {
        let value = parseJson("42")
        let schema = parseJson("false")
        @Assert(isValidSchema(value, schema), false)
    }

    // ── Complex schema tests ────────────────────────────────────────────

    @TestCase
    public func testComplexPersonSchema(): Unit {
        let schema = parseJson("""
        {
            "type": "object",
            "required": ["name"],
            "properties": {
                "name": {"type": "string", "minLength": 1},
                "age": {"type": "integer", "minimum": 0, "maximum": 150},
                "email": {"type": "string"},
                "tags": {
                    "type": "array",
                    "items": {"type": "string"}
                }
            }
        }
        """)

        let validPerson = parseJson("{\"name\":\"Alice\",\"age\":30,\"email\":\"alice@test.com\",\"tags\":[\"dev\",\"admin\"]}")
        @Assert(isValidSchema(validPerson, schema), true)

        let invalidPerson = parseJson("{\"name\":\"\",\"age\":-5}")
        @Assert(isValidSchema(invalidPerson, schema), false)
    }

    // ── Error reporting tests ───────────────────────────────────────────

    @TestCase
    public func testValidationErrorPath(): Unit {
        let value = parseJson("{\"name\":\"A\"}")
        let schema = parseJson("{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"minLength\":2}}}")

        match (validateSchema(value, schema)) {
            case Valid => @Assert(false, true)
            case Invalid(errors) =>
                @Assert(errors.size > 0, true)
                @Assert(errors[0].path.contains("name"), true)
        }
    }

    @TestCase
    public func testMultipleErrors(): Unit {
        let value = parseJson("{\"name\":\"\",\"age\":-1}")
        let schema = parseJson("{\"type\":\"object\",\"required\":[\"name\",\"age\",\"email\"],\"properties\":{\"name\":{\"type\":\"string\",\"minLength\":1},\"age\":{\"type\":\"integer\",\"minimum\":0}}}")

        match (validateSchema(value, schema)) {
            case Valid => @Assert(false, true)
            case Invalid(errors) =>
                @Assert(errors.size >= 2, true)  // Missing email + invalid name + invalid age
        }
    }

    // ── Pattern (regex) tests ─────────────────────────────────────────────

    @TestCase
    public func testPatternValid(): Unit {
        let value = parseJson("\"hello123\"")
        let schema = parseJson("{\"type\":\"string\",\"pattern\":\"^[a-z0-9]+$\"}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testPatternInvalid(): Unit {
        let value = parseJson("\"hello world\"")
        let schema = parseJson("{\"type\":\"string\",\"pattern\":\"^[a-z0-9]+$\"}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testPatternEmail(): Unit {
        let schema = parseJson("{\"type\":\"string\",\"pattern\":\"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}$\"}")

        let validEmail = parseJson("\"test@example.com\"")
        @Assert(isValidSchema(validEmail, schema), true)

        let invalidEmail = parseJson("\"not-an-email\"")
        @Assert(isValidSchema(invalidEmail, schema), false)
    }

    @TestCase
    public func testPatternPhone(): Unit {
        let schema = parseJson("{\"type\":\"string\",\"pattern\":\"^\\\\d{3}-\\\\d{3}-\\\\d{4}$\"}")

        let validPhone = parseJson("\"123-456-7890\"")
        @Assert(isValidSchema(validPhone, schema), true)

        let invalidPhone = parseJson("\"1234567890\"")
        @Assert(isValidSchema(invalidPhone, schema), false)
    }

    @TestCase
    public func testPatternInObjectProperty(): Unit {
        let schema = parseJson("""
        {
            "type": "object",
            "properties": {
                "email": {
                    "type": "string",
                    "pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}$"
                }
            }
        }
        """)

        let valid = parseJson("{\"email\":\"user@example.com\"}")
        @Assert(isValidSchema(valid, schema), true)

        let invalid = parseJson("{\"email\":\"invalid\"}")
        @Assert(isValidSchema(invalid, schema), false)
    }

    // ── MultipleOf tests ─────────────────────────────────────────────────

    @TestCase
    public func testMultipleOfValid(): Unit {
        let value = parseJson("10")
        let schema = parseJson("{\"type\":\"integer\",\"multipleOf\":5}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testMultipleOfInvalid(): Unit {
        let value = parseJson("7")
        let schema = parseJson("{\"type\":\"integer\",\"multipleOf\":5}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testMultipleOfFloat(): Unit {
        let value = parseJson("1.5")
        let schema = parseJson("{\"type\":\"number\",\"multipleOf\":0.5}")
        @Assert(isValidSchema(value, schema), true)
    }

    @TestCase
    public func testMultipleOfFloatInvalid(): Unit {
        let value = parseJson("1.3")
        let schema = parseJson("{\"type\":\"number\",\"multipleOf\":0.5}")
        @Assert(isValidSchema(value, schema), false)
    }

    @TestCase
    public func testMultipleOfTwo(): Unit {
        let schema = parseJson("{\"type\":\"integer\",\"multipleOf\":2}")

        @Assert(isValidSchema(parseJson("4"), schema), true)
        @Assert(isValidSchema(parseJson("6"), schema), true)
        @Assert(isValidSchema(parseJson("5"), schema), false)
        @Assert(isValidSchema(parseJson("7"), schema), false)
    }

    @TestCase
    public func testMultipleOfInObject(): Unit {
        let schema = parseJson("""
        {
            "type": "object",
            "properties": {
                "quantity": {
                    "type": "integer",
                    "multipleOf": 10
                }
            }
        }
        """)

        let valid = parseJson("{\"quantity\":30}")
        @Assert(isValidSchema(valid, schema), true)

        let invalid = parseJson("{\"quantity\":25}")
        @Assert(isValidSchema(invalid, schema), false)
    }
}
