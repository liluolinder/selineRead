macro package CJson.jsonmacro

import std.ast.*

class ClassJsonSerilizer <: ClassProcessor {
    
    public init(globalConfig: GlobalConfig) {
        super(globalConfig)
    }
    
    /*
    * Makes  toJsonObject() and toJson() func of target class
    *
    * @param var_Tk_List the list for memeber var token of the target class
    * @return Tokens the toJsonObject() and toJson() func of target class represented in tokens
    */
    public func makeToJsonFunc(var_Tk_List: ArrayList<VarDecl>): Tokens {
        
        return quote(
            public func toJsonValue(): JsonObject {
                var map: HashMap<String, JsonValue> = HashMap()
                $(composeMap(var_Tk_List))
                return JsonObject(map)
            }

            public func toJson(): String {
                this.toJsonValue().toString()
            }
        )
    }

    private func composeMap(var_Tk_List: ArrayList<VarDecl>): Tokens {
        var fieldMapToken = Tokens()
        
        for(var_Tk in var_Tk_List) {
            fieldMapToken = fieldMapToken + addFieldToMap(var_Tk)
        }

        return fieldMapToken
    }

    private func addFieldToMap(var_Tk: VarDecl): Tokens {
        let varInfo = getVarInfo(var_Tk)
        var mappedNameValue = getMappedName(varInfo.name)

        if (globalConfig.propAdaptorFactry.hasAdaptor(varInfo.identifier.toTokens().toString())) {
            //1. custom property with @JsonCust[Serializer]
            addCustProp(mappedNameValue, varInfo)

        } else if (varInfo.typeName.toTokens().toString().contains("Option")) {
            //2. Option<T> property
            addOptionPorp(mappedNameValue, varInfo)
        } else {
            //3. normal property
            addProp(mappedNameValue, varInfo)
        }
    }

    private func addCustProp(key: String, varInfo: VarInfo): Tokens {
        var identString = varInfo.identifier.toTokens().toString()
        let serializer_Tk = Token(TokenKind.IDENTIFIER, globalConfig.propAdaptorFactry.getAdaptor(identString))
        return quote(
            map.add($key, $serializer_Tk(this.$(varInfo.identifier)).toJsonValue())
        )
    }

    private func addOptionPorp(key: String, varInfo: VarInfo): Tokens {
        return quote(
            if (let Some(v) <- this.$(varInfo.identifier)) {
                map.add($key, v.toJsonValue())
            } else {
                map.add($key, JsonNull())
            }
        )
    }

    private func addProp(key: String, varInfo: VarInfo): Tokens {
        return quote(
            map.add($key, this.$(varInfo.identifier).toJsonValue())
        )
    }
}