package seajson

// ============================================================================
// JSON Schema Validation (Draft-07 subset)
// ============================================================================
//
// Implements a subset of JSON Schema Draft-07 for validation:
// https://json-schema.org/draft-07/json-schema-release-notes.html
//
// Supported keywords:
//   - type: string, number, integer, boolean, object, array, null
//   - required: array of required property names
//   - properties: object property schemas
//   - minimum, maximum: numeric range constraints
//   - exclusiveMinimum, exclusiveMaximum: exclusive numeric bounds
//   - minLength, maxLength: string length constraints
//   - pattern: regex pattern for string validation
//   - minItems, maxItems: array size constraints
//   - enum: enumeration of allowed values
//   - const: single allowed value
//
// Example:
//   let schema = parseJson("{
//     \"type\": \"object\",
//     \"required\": [\"name\"],
//     \"properties\": {
//       \"name\": {\"type\": \"string\", \"minLength\": 1},
//       \"email\": {\"type\": \"string\", \"pattern\": \"^[a-zA-Z0-9.+%-]+@.+$\"},
//       \"age\": {\"type\": \"integer\", \"minimum\": 0}
//     }
//   }")
//   let result = validateSchema(value, schema)
//
// ============================================================================

import std.collection.ArrayList
import std.regex.*

/// Schema validation error
public class SchemaError {
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        this.path = path
        this.message = message
    }

    public func toString(): String {
        "SchemaError at ${path}: ${message}"
    }
}

/// Schema validation result
public enum SchemaResult {
    | Valid
    | Invalid(ArrayList<SchemaError>)
}

/// Validate a JsonValue against a JSON Schema
public func validateSchema(value: JsonValue, schema: JsonValue): SchemaResult {
    let errors = ArrayList<SchemaError>()
    validateRecursive(value, schema, "$", errors)
    if (errors.size == 0) {
        Valid
    } else {
        Invalid(errors)
    }
}

/// Check if a value is valid against a schema (returns bool)
public func isValidSchema(value: JsonValue, schema: JsonValue): Bool {
    match (validateSchema(value, schema)) {
        case Valid => true
        case Invalid(_) => false
    }
}

// ── Internal validation logic ───────────────────────────────────────

private func validateRecursive(value: JsonValue, schema: JsonValue, path: String, errors: ArrayList<SchemaError>): Unit {
    // Handle boolean schemas
    match (schema) {
        case JsonBoolVal(true) => return  // Always valid
        case JsonBoolVal(false) =>
            errors.add(SchemaError(path, "schema is false, value is always invalid"))
            return
        case _ => ()
    }

    // Schema must be an object at this point
    if (!isJsonObject(schema)) {
        errors.add(SchemaError(path, "schema must be an object or boolean"))
        return
    }

    // Validate type
    match (jsonFieldString(schema, "type")) {
        case Some(typeStr) =>
            if (!validateType(value, typeStr)) {
                errors.add(SchemaError(path, "expected type '${typeStr}', got '${getTypeName(value)}'"))
                return  // Stop on type mismatch
            }
        case None => ()
    }

    // Validate const
    match (jsonField(schema, "const")) {
        case Some(constVal) =>
            if (!valuesEqual(value, constVal)) {
                errors.add(SchemaError(path, "value does not match const"))
            }
        case None => ()
    }

    // Validate enum
    match (jsonFieldArr(schema, "enum")) {
        case Some(enumArr) =>
            if (!isInEnum(value, enumArr)) {
                errors.add(SchemaError(path, "value is not in enum"))
            }
        case None => ()
    }

    // Type-specific validations
    match (value) {
        case JsonStrVal(_) => validateString(value, schema, path, errors)
        case JsonIntVal(_) | JsonInt32Val(_) | JsonFloatVal(_) => validateNumber(value, schema, path, errors)
        case JsonObjVal(_) => validateObject(value, schema, path, errors)
        case JsonArrVal(_) => validateArray(value, schema, path, errors)
        case _ => ()
    }
}

private func validateType(value: JsonValue, typeStr: String): Bool {
    match (typeStr) {
        case "string" => isJsonString(value)
        case "number" => isJsonNumber(value)
        case "integer" => isJsonInteger(value)
        case "boolean" => isJsonBool(value)
        case "object" => isJsonObject(value)
        case "array" => isJsonArray(value)
        case "null" => isJsonNull(value)
        case _ => true  // Unknown type, skip validation
    }
}

private func getTypeName(value: JsonValue): String {
    match (value) {
        case JsonNull => "null"
        case JsonBoolVal(_) => "boolean"
        case JsonIntVal(_) | JsonInt32Val(_) => "integer"
        case JsonFloatVal(_) => "number"
        case JsonStrVal(_) => "string"
        case JsonArrVal(_) => "array"
        case JsonObjVal(_) => "object"
    }
}

private func isJsonInteger(value: JsonValue): Bool {
    match (value) {
        case JsonIntVal(_) => true
        case JsonInt32Val(_) => true
        case _ => false
    }
}

private func validateString(value: JsonValue, schema: JsonValue, path: String, errors: ArrayList<SchemaError>): Unit {
    let s = jsonAsStringOr(value, "")

    // minLength
    match (jsonFieldInt(schema, "minLength")) {
        case Some(minLen) =>
            if (s.size < minLen) {
                errors.add(SchemaError(path, "string length ${s.size} is less than minLength ${minLen}"))
            }
        case None => ()
    }

    // maxLength
    match (jsonFieldInt(schema, "maxLength")) {
        case Some(maxLen) =>
            if (s.size > maxLen) {
                errors.add(SchemaError(path, "string length ${s.size} is greater than maxLength ${maxLen}"))
            }
        case None => ()
    }

    // pattern (regex validation)
    match (jsonFieldString(schema, "pattern")) {
        case Some(patternStr) =>
            let regex = Regex(patternStr)
            if (regex.find(s).isNone()) {
                errors.add(SchemaError(path, "string '${s}' does not match pattern '${patternStr}'"))
            }
        case None => ()
    }
}

private func validateNumber(value: JsonValue, schema: JsonValue, path: String, errors: ArrayList<SchemaError>): Unit {
    let n = jsonAsFloatOr(value, 0.0)

    // minimum (can be int or float in schema)
    match (jsonField(schema, "minimum")) {
        case Some(JsonFloatVal(minVal)) =>
            if (n < minVal) {
                errors.add(SchemaError(path, "value ${n} is less than minimum ${minVal}"))
            }
        case Some(JsonIntVal(minVal)) =>
            if (n < Float64(minVal)) {
                errors.add(SchemaError(path, "value ${n} is less than minimum ${minVal}"))
            }
        case Some(JsonInt32Val(minVal)) =>
            if (n < Float64(minVal)) {
                errors.add(SchemaError(path, "value ${n} is less than minimum ${minVal}"))
            }
        case _ => ()
    }

    // maximum (can be int or float in schema)
    match (jsonField(schema, "maximum")) {
        case Some(JsonFloatVal(maxVal)) =>
            if (n > maxVal) {
                errors.add(SchemaError(path, "value ${n} is greater than maximum ${maxVal}"))
            }
        case Some(JsonIntVal(maxVal)) =>
            if (n > Float64(maxVal)) {
                errors.add(SchemaError(path, "value ${n} is greater than maximum ${maxVal}"))
            }
        case Some(JsonInt32Val(maxVal)) =>
            if (n > Float64(maxVal)) {
                errors.add(SchemaError(path, "value ${n} is greater than maximum ${maxVal}"))
            }
        case _ => ()
    }

    // exclusiveMinimum
    match (jsonField(schema, "exclusiveMinimum")) {
        case Some(JsonFloatVal(minVal)) =>
            if (n <= minVal) {
                errors.add(SchemaError(path, "value ${n} is not greater than exclusiveMinimum ${minVal}"))
            }
        case Some(JsonIntVal(minVal)) =>
            if (n <= Float64(minVal)) {
                errors.add(SchemaError(path, "value ${n} is not greater than exclusiveMinimum ${minVal}"))
            }
        case Some(JsonInt32Val(minVal)) =>
            if (n <= Float64(minVal)) {
                errors.add(SchemaError(path, "value ${n} is not greater than exclusiveMinimum ${minVal}"))
            }
        case _ => ()
    }

    // exclusiveMaximum
    match (jsonField(schema, "exclusiveMaximum")) {
        case Some(JsonFloatVal(maxVal)) =>
            if (n >= maxVal) {
                errors.add(SchemaError(path, "value ${n} is not less than exclusiveMaximum ${maxVal}"))
            }
        case Some(JsonIntVal(maxVal)) =>
            if (n >= Float64(maxVal)) {
                errors.add(SchemaError(path, "value ${n} is not less than exclusiveMaximum ${maxVal}"))
            }
        case Some(JsonInt32Val(maxVal)) =>
            if (n >= Float64(maxVal)) {
                errors.add(SchemaError(path, "value ${n} is not less than exclusiveMaximum ${maxVal}"))
            }
        case _ => ()
    }

    // multipleOf - value must be a multiple of this number
    match (jsonField(schema, "multipleOf")) {
        case Some(JsonFloatVal(multiple)) =>
            if (multiple > 0.0) {
                let quotient = n / multiple
                let rounded = Float64(Int64(quotient + 0.5))
                // Check if quotient is close to an integer
                let diff = if (quotient >= rounded) { quotient - rounded } else { rounded - quotient }
                if (diff > 1e-9) {
                    errors.add(SchemaError(path, "value ${n} is not a multiple of ${multiple}"))
                }
            }
        case Some(JsonIntVal(multiple)) =>
            if (multiple > 0) {
                let mFloat = Float64(multiple)
                let quotient = n / mFloat
                let rounded = Float64(Int64(quotient + 0.5))
                let diff = if (quotient >= rounded) { quotient - rounded } else { rounded - quotient }
                if (diff > 1e-9) {
                    errors.add(SchemaError(path, "value ${n} is not a multiple of ${multiple}"))
                }
            }
        case Some(JsonInt32Val(multiple)) =>
            if (multiple > 0) {
                let mFloat = Float64(multiple)
                let quotient = n / mFloat
                let rounded = Float64(Int64(quotient + 0.5))
                let diff = if (quotient >= rounded) { quotient - rounded } else { rounded - quotient }
                if (diff > 1e-9) {
                    errors.add(SchemaError(path, "value ${n} is not a multiple of ${multiple}"))
                }
            }
        case _ => ()
    }
}

private func validateObject(value: JsonValue, schema: JsonValue, path: String, errors: ArrayList<SchemaError>): Unit {
    // required
    match (jsonField(schema, "required")) {
        case Some(JsonArrVal(requiredArr)) =>
            var i: Int64 = 0
            while (i < requiredArr.size) {
                let reqField = requiredArr[i]
                match (reqField) {
                    case JsonStrVal(fieldName) =>
                        if (!jsonHasKey(value, fieldName)) {
                            errors.add(SchemaError(path, "missing required property '${fieldName}'"))
                        }
                    case _ => ()
                }
                i += 1
            }
        case _ => ()
    }

    // properties
    match (jsonFieldObj(schema, "properties")) {
        case Some(propertiesSchema) =>
            match (propertiesSchema) {
                case JsonObjVal(entries) =>
                    var i: Int64 = 0
                    while (i < entries.size) {
                        let (propName, propSchema) = entries[i]
                        match (jsonField(value, propName)) {
                            case Some(propValue) =>
                                validateRecursive(propValue, propSchema, "${path}.${propName}", errors)
                            case None => ()
                        }
                        i += 1
                    }
                case _ => ()
            }
        case None => ()
    }
}

private func validateArray(value: JsonValue, schema: JsonValue, path: String, errors: ArrayList<SchemaError>): Unit {
    let arrSize = jsonArrSize(value)

    // minItems
    match (jsonFieldInt(schema, "minItems")) {
        case Some(minItems) =>
            if (arrSize < minItems) {
                errors.add(SchemaError(path, "array size ${arrSize} is less than minItems ${minItems}"))
            }
        case None => ()
    }

    // maxItems
    match (jsonFieldInt(schema, "maxItems")) {
        case Some(maxItems) =>
            if (arrSize > maxItems) {
                errors.add(SchemaError(path, "array size ${arrSize} is greater than maxItems ${maxItems}"))
            }
        case None => ()
    }

    // items (schema for all items)
    match (jsonField(schema, "items")) {
        case Some(itemsSchema) =>
            match (value) {
                case JsonArrVal(items) =>
                    var i: Int64 = 0
                    while (i < items.size) {
                        validateRecursive(items[i], itemsSchema, "${path}[${i}]", errors)
                        i += 1
                    }
                case _ => ()
            }
        case None => ()
    }
}

private func valuesEqual(a: JsonValue, b: JsonValue): Bool {
    match (a) {
        case JsonNull =>
            match (b) {
                case JsonNull => true
                case _ => false
            }
        case JsonBoolVal(ba) =>
            match (b) {
                case JsonBoolVal(bb) => ba == bb
                case _ => false
            }
        case JsonIntVal(ia) =>
            match (b) {
                case JsonIntVal(ib) => ia == ib
                case JsonInt32Val(ib) => ia == Int64(ib)
                case _ => false
            }
        case JsonInt32Val(ia) =>
            match (b) {
                case JsonIntVal(ib) => Int64(ia) == ib
                case JsonInt32Val(ib) => ia == ib
                case _ => false
            }
        case JsonFloatVal(fa) =>
            match (b) {
                case JsonFloatVal(fb) => fa == fb
                case _ => false
            }
        case JsonStrVal(sa) =>
            match (b) {
                case JsonStrVal(sb) => sa == sb
                case _ => false
            }
        case JsonArrVal(itemsA) =>
            match (b) {
                case JsonArrVal(itemsB) =>
                    if (itemsA.size != itemsB.size) {
                        false
                    } else {
                        var i: Int64 = 0
                        var equal = true
                        while (i < itemsA.size && equal) {
                            if (!valuesEqual(itemsA[i], itemsB[i])) {
                                equal = false
                            }
                            i += 1
                        }
                        equal
                    }
                case _ => false
            }
        case JsonObjVal(entriesA) =>
            match (b) {
                case JsonObjVal(entriesB) =>
                    if (entriesA.size != entriesB.size) {
                        false
                    } else {
                        var equal = true
                        var i: Int64 = 0
                        while (i < entriesA.size && equal) {
                            let (key, valA) = entriesA[i]
                            match (jsonField(b, key)) {
                                case Some(valB) =>
                                    if (!valuesEqual(valA, valB)) {
                                        equal = false
                                    }
                                case None => equal = false
                            }
                            i += 1
                        }
                        equal
                    }
                case _ => false
            }
    }
}

private func isInEnum(value: JsonValue, enumArr: JsonValue): Bool {
    match (enumArr) {
        case JsonArrVal(items) =>
            var i: Int64 = 0
            while (i < items.size) {
                if (valuesEqual(value, items[i])) {
                    return true
                }
                i += 1
            }
            false
        case _ => false
    }
}
