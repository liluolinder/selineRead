macro package CJson.jsonmacro

import std.ast.{Token, TypeNode}
import std.collection.ArrayList

class VarInfo {
    public VarInfo(public let identifier: Token,
                    public let name: String,
                    public let typeName: String,
                    public let typeArguments: ArrayList<TypeNode>) {
    }
}