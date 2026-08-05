macro package CJson.jsonmacro

import std.ast.*

/*
* Macro for ignore the decorated var when doing json serialization/deserialization
* @param input_Tk the target var
* @return token the expaned token representation
*/
public macro JsonIgnore(input_Tk: Tokens): Tokens {
    var decl = TokenVerifier.verifyVarDecl(input_Tk, Const.JSON_IGNORE_MARCO_NAME)
    
    globalConfig.ignoredVarSet.add(decl.identifier.value)

    return input_Tk
}
