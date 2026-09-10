macro package CJson.jsonmacro

import std.ast.*
internal import std.collection.*

/*
* Serializer of json for target class
*/
class ClassJsonDeserilizer <: ClassProcessor {

    public init(globalConfig: GlobalConfig) {
        super(globalConfig)
    }

    /*
    * Makes fromJson() func of target class
    *
    * @param classIdentity_Tk the Identifier token for target class
    * @param var_Tk_List the list for memeber var token of the target class
    * @return Tokens the fromJson() func of target class represented in tokens
    */  
    public func makeFromJsonFunc(classIdentity_Tk: Token, var_Tk_List: ArrayList<VarDecl>): Tokens {
        
        var jsonOjbectToken = Token(TokenKind.IDENTIFIER, "jsonObject")
        return quote(
            public static func fromJson(json: String): $classIdentity_Tk {
                return $classIdentity_Tk.fromJsonValue(JsonValue.fromStr(json))
            }

            public static func fromJsonValue(json: JsonValue): $classIdentity_Tk {
                var ret = $classIdentity_Tk()
                var $jsonOjbectToken = json.asObject()
                $(parseJsonFields(var_Tk_List, jsonOjbectToken))
                return ret
            }
        )
    }

    private func parseJsonFields(filedInfoList: ArrayList<VarDecl>, jsonOjbect_Tk: Token): Tokens {
        var fieldParseToken = Tokens()
        
        for(fieldInfo in filedInfoList) {
            fieldParseToken = fieldParseToken +  parseJsonFiled(fieldInfo, jsonOjbect_Tk)
        }

        return fieldParseToken
    }

    private func parseJsonFiled(var_Tk: VarDecl, jsonOjbectVar_Tk: Token): Tokens {
        let varInfo = getVarInfo(var_Tk)
        var mappedNameValue = getMappedName(varInfo.name)
        let getFieldCore_Tk = parseJsonFiledCore(var_Tk, jsonOjbectVar_Tk, varInfo)

        return quote(
            if($jsonOjbectVar_Tk.getFields().contains($mappedNameValue)) {
                $getFieldCore_Tk
            }
        )
    }

    private func parseJsonFiledCore(var_Tk: VarDecl, jsonOjbectVar_Tk: Token, varInfo: VarInfo): Tokens {
        var mappedNameValue = getMappedName(varInfo.name)
        var nodeJson_Tk = quote($jsonOjbectVar_Tk.get($mappedNameValue).getOrThrow())
        var valueReveiver_Tk = quote(ret.$(varInfo.identifier))

        if (globalConfig.propAdaptorFactry.hasAdaptor(varInfo.identifier.toTokens().toString())) {
            //1. custom property with @JsonCust[Serializer]
            return getCustProp(nodeJson_Tk, varInfo)
        } else if (varInfo.typeName == "Option") {
            //2. Option<T> property
            return getOptionPorp(nodeJson_Tk, varInfo)
        } else if (varInfo.typeArguments.size > 0) {
            //3. Generic property such as ArrayList, HashSet, HashMap
            getGenericProp(nodeJson_Tk, varInfo)
        } else {
            //4. Primitive property
            getProp(nodeJson_Tk, varInfo)
        }
    }

    private func getCustProp(nodeJson_Tk: Tokens, varInfo: VarInfo): Tokens {
        let serializer_Tk = Token(TokenKind.IDENTIFIER, 
            globalConfig.propAdaptorFactry.getAdaptor(varInfo.identifier.toTokens().toString()))
            
        return quote(
            ret.$(varInfo.identifier) = $serializer_Tk.fromJsonValue($nodeJson_Tk)
        )
    }

    private func getOptionPorp(nodeJson_Tk: Tokens, varInfo: VarInfo): Tokens {
        if (varInfo.typeArguments.size == 0) {
            throw Exception("Option generic type not provided")
        }

        let optionType = varInfo.typeArguments[0]
        return quote(
            if ($nodeJson_Tk is JsonNull) {
                ret.$(varInfo.identifier) = Option<$optionType>.None
            } else {
                try {
                    ret.$(varInfo.identifier) = $optionType.fromJsonValue($nodeJson_Tk)
                } catch(exp: Exception) {
                    ret.$(varInfo.identifier) = Option<$optionType>.None
                }
            }
        )
    }

    private func getGenericProp(nodeJson_Tk: Tokens, varInfo: VarInfo): Tokens {
        var serializer_Tk = Token(TokenKind.IDENTIFIER, varInfo.typeName)
        var genericType_Tk = varInfo.typeArguments.flattenWithComma()
        return quote(
            ret.$(varInfo.identifier) = $serializer_Tk<$genericType_Tk>.fromJsonValue($nodeJson_Tk)
        )
    }

    private func getProp(nodeJson_Tk: Tokens, varInfo: VarInfo): Tokens {
        var serializer_Tk = Token(TokenKind.IDENTIFIER, varInfo.typeName)
        return quote(
            ret.$(varInfo.identifier) = $serializer_Tk.fromJsonValue($nodeJson_Tk)
        )
    }
}
