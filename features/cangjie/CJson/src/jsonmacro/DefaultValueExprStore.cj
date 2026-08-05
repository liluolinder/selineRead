macro package CJson.jsonmacro

import std.ast.*

interface DefaultValueExprStore {
    func hasValueExpr(varIdentifierName: String): Bool
    func getValueExpr(varIdentifierName: String): Expr
}
