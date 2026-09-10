macro package CJson.jsonmacro

import std.ast.*

/*
* The global configuration
*/
class GlobalConfig <: DefaultValueExprStore {
    public var propAdaptorFactry = JsonPropAdaptorFactory()

    public let userDefinedVarMap : HashMap<String, String> = HashMap()
    public let ignoredVarSet: HashSet<String> = HashSet()
    public var defaultValueMap: Map<String, Expr> = HashMap()

    /*
    * Resets the configs for the next class instance, including usr defined var name mapping and ignored vars
    */
    public func reset() {
        this.userDefinedVarMap.clear()
        this.ignoredVarSet.clear()
        this.propAdaptorFactry = JsonPropAdaptorFactory()
    }

    public func hasValueExpr(varIdentifierName: String) {
        return defaultValueMap.contains(varIdentifierName)
    }

    public func getValueExpr(varIdentifierName: String) {
        return defaultValueMap.get(varIdentifierName).getOrThrow()
    }
}