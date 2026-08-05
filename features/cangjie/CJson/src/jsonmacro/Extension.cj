macro package CJson.jsonmacro

import std.ast.*
import std.collection.ArrayList

interface TokenExtesion {

}

extend TypeNode <: TokenExtesion {

    /*
    * Gets the type name
    *
    * @return String the name of the type
    */
    public func getTypeName(): String {
        if (this is RefType) {
            return (this as RefType).getOrThrow().identifier.value
        } else if (this is PrimitiveType) {
            return (this as PrimitiveType).getOrThrow().keyword.value
        } else if (this is PrefixType) {
            throw TypeInferrenceException("Option type expressed as '?Type' is currently not supported, plese use 'Option<Type>' instead: ${this.toTokens()}")
        } else {
            throw TypeInferrenceException("Error when try to get type name for ${this.toTokens()}")
        }
    }
}

extend VarDecl <: TokenExtesion {

    /*
     * Get info from VarDecl
     *
     * @return VarInfo
     */
    public func getVarInfo(): VarInfo {
        let identifier = identifier
        let name = identifier.value
        var typeName: String
        var typeArguments = ArrayList<TypeNode>()

        try {
            typeName = this.declType.getTypeName()
            if (this.declType is RefType) {
                let refType = (this.declType as RefType).getOrThrow()
                typeArguments = refType.typeArguments
            }
            
        } catch (exp: NoneValueException) {
            throw TypeInferrenceException("Field ${name} must be declared with a specific type instead of using a inferred type")
        }
        return VarInfo(identifier, name, typeName, typeArguments)
    }
}

extend ArrayList<TypeNode> <: TokenExtesion {
    public func flattenWithComma(): Tokens {
        var res_Tks = quote()
        for (typeNode in this) {
            res_Tks.append(typeNode)
            res_Tks.append(Token(COMMA))
        }

        res_Tks.remove(res_Tks.size - 1)
        return res_Tks
    }
}