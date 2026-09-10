macro package CJson.jsonmacro

import std.ast.*

struct ClassAndStructInfo {
    public var varDeclList = ArrayList<VarDecl>()
    public var classModifier = ArrayList<Modifier>()
    public var classKeyWord = Token()
    public var classIdent = Token()
    public var classBody = ArrayList<Decl>()
    public var superTypes = ArrayList<TypeNode>()

    public func composeWithJsonFunc(globalConfig: GlobalConfig) {
        let fromJsonFunc = ClassJsonDeserilizer(globalConfig).makeFromJsonFunc(classIdent, varDeclList)
        let toJsonFunc = ClassJsonSerilizer(globalConfig).makeToJsonFunc(varDeclList)

        //reset global config next class
        globalConfig.reset()
        
        var superTypeExpr = Tokens()
        if (superTypes.size != 0) {
            superTypeExpr = quote(<: $superTypes & IJsonSerializable<$classIdent>)
        } else {
            superTypeExpr = quote(<: IJsonSerializable<$classIdent>)
        }

        return quote(
            $classModifier $classKeyWord $classIdent $superTypeExpr {
                $classBody
                $fromJsonFunc
                $toJsonFunc
            }
        )
    }
}