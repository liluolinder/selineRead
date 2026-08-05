macro package CJson.jsonmacro

import std.ast.*

/*
* Macro for inserting json serialization/deserialization func onto target class
* @param input_Tk the target class token
* @return token the expaned token representation
*/
public macro JsonSerializable(input_Tk: Tokens): Tokens {
    let declPair = TokenVerifier.verifyClassDecl(input_Tk, Const.JSON_SERIALIZABLE_MACRO_NAME)

    var classAndStructInfo = ClassAndStructInfo()

    match(declPair) {
        case (Some(vc), None) =>
            classAndStructInfo.classModifier = vc.modifiers
            classAndStructInfo.classKeyWord = vc.keyword
            classAndStructInfo.classIdent = vc.identifier
            classAndStructInfo.classBody = vc.body.decls
            classAndStructInfo.superTypes = vc.superTypes
            classAndStructInfo.varDeclList = checkVars(vc, globalConfig)
        case (None, Some(vs)) => 
            classAndStructInfo.classModifier = vs.modifiers
            classAndStructInfo.classKeyWord = vs.keyword
            classAndStructInfo.classIdent = vs.identifier
            classAndStructInfo.classBody = vs.body.decls
            classAndStructInfo.superTypes = vs.superTypes
            classAndStructInfo.varDeclList = checkVars(vs, globalConfig)

        case _ => ()
    }

    var messages = getChildMessages(Const.JSON_CUST_MARCO_NAME)
    for (msg in messages) {
        let propName = msg.getString(Const.KEY_PROP)
        let serializer = msg.getString(Const.KEY_SERIALIZER)
        if ( propName != "" && serializer != "") {
            globalConfig.propAdaptorFactry.registrer(propName, serializer)
        }
    }

    try {
        return classAndStructInfo.composeWithJsonFunc(globalConfig)
    } catch(exp: AdaptorMissingException | TypeInferrenceException ) {
        throw MacroExpansionException("Exception when expending JsonSerializable at class/struct ${classAndStructInfo.classIdent.value} : " + exp.message)
    }
}


func checkVars(classDecl_Tk: Node, globalConfig: GlobalConfig): ArrayList<VarDecl> {
    let varVisitor = ClassVarDeclVisitor(globalConfig)
    classDecl_Tk.traverse(varVisitor)
    globalConfig.defaultValueMap = varVisitor.getDefaultVarValueMap()
    return varVisitor.getVarTokenList()
}