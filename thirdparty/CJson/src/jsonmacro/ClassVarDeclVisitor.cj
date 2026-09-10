macro package CJson.jsonmacro

import std.ast.*

/*
*  The visitor for class-level vars for target class
*/
class ClassVarDeclVisitor <: Visitor {
    private var var_Tk_List: ArrayList<VarDecl> = ArrayList()
    private var defaultVarValueMap: Map<String, Expr> = HashMap()

    private var globalConfig: GlobalConfig

    public init(globalConfig: GlobalConfig) {
        this.globalConfig = globalConfig
    }

    /*
    * Gets the class level var token list
    *
    * @return the list of tokens with var
    */
    public func getVarTokenList(): ArrayList<VarDecl> {
        return var_Tk_List
    }

    /*
    * Gets the map that stores the default values for vars
    *
    * @return the map of default values with <VarName, DefaultVarValue>
    */
    public func getDefaultVarValueMap(): Map<String, Expr> {
        return defaultVarValueMap
    }

    /*
    * Set the default value of the var
    */
    private func setDefaultValue(varDecl_Tk: VarDecl): Unit { 
        try {
            defaultVarValueMap.add(varDecl_Tk.identifier.value, varDecl_Tk.expr)
        } catch (_: ASTException) {
            ()
        }
    }

    /*
    * Implementation of class var visiting strategy, only visiting class-level vars perform related operations
    *
    * @return true if wants to continue visisting
    */
    override public func visit(varDecl: VarDecl) {
        if (!globalConfig.ignoredVarSet.contains(varDecl.identifier.value)) {
            setDefaultValue(varDecl)
            var_Tk_List.add(varDecl)
        }
    }

    override public func visit(funcDecl: FuncDecl) {
        breakTraverse()
    }
}
