macro package CJson.jsonmacro

import std.ast.*

/*
* Macro for custom json var name mapping
* @param attr_Tk the given name for mapping
* @param input_Tk the target var
* @return token the expaned token representation
*/
public macro JsonCust(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    var decl = TokenVerifier.verifyVarDecl(input_Tk, Const.JSON_NAME_MARCO_NAME)
    
    assertParentContext("JsonSerializable")
    setItem("prop", decl.identifier.value)
    setItem("serializer", attr_Tk.toString())
    
    return input_Tk
}