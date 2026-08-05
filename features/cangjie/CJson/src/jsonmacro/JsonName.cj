macro package CJson.jsonmacro

import std.ast.*

/*
* Macro for custom json var name mapping
* @param attr_Tk the given name for mapping
* @param input_Tk the target var
* @return token the expaned token representation
*/
public macro JsonName(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    var decl = TokenVerifier.verifyVarDecl(input_Tk, Const.JSON_NAME_MARCO_NAME)
    
    globalConfig.userDefinedVarMap.add(decl.identifier.value, checkVarNameAttr(attr_Tk))
    
    return input_Tk
}

func checkVarNameAttr(attr_Tk: Tokens): String {
    var token = attr_Tk[0]
    if (token.kind == STRING_LITERAL) {
        return token.value
    } else {
        throw MacroParameterException("JsonAttribute requies a string parameter at position 0, find ${token.kind} instead") 
    }
    
}