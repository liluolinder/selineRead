macro package CJson.jsonmacro

import std.ast.*

/*
* Verifier for tokens
*/
class TokenVerifier {
    /*
    * Verifies class decl token
    * @param input_Tk the token to verify
    * @marcoName the marco name to check against
    * @return NodeFormat_ClassDecl the input token as NodeFormat_ClassDecl type
    */
    public static func verifyClassDecl(input_Tk: Tokens, marcoName: String): (Option<ClassDecl>, Option<StructDecl>) {
        var decl = parseDecl(input_Tk)

        if (decl is ClassDecl) {
            return ((decl as ClassDecl), None)
        } else if (decl is StructDecl) {
            return (None, (decl as StructDecl))
        } else {
            throw TokenVerificationException("${marcoName} is only allowed for class or struct")
        }

        
    }

    /*
    * Verifies var decl token
    * @param input_Tk the token to verify
    * @marcoName the marco name to check against
    * @return NodeFormat_ClassDecl the input token as VarDecl type
    */
    public static func verifyVarDecl(input_Tk: Tokens, marcoName: String): VarDecl {
        var decl = parseDecl(input_Tk)

        if (!(decl is VarDecl)) {
            throw TokenVerificationException("${marcoName} is noly allow for class level vars")
        }

        return (decl as VarDecl).getOrThrow()
    }
}
  