macro package CJson.jsonmacro

import std.collection.HashMap

/*
* The factory for json adaptors
*/
class JsonPropAdaptorFactory {
    private let map: HashMap<String, String> = HashMap()
    private static const separator = ":"
    
    /*
    * Registers the adaptor by identifier
    * @param identifier the identifier
    * @param adaptor the adaptor to register
    */
    public func registrer(propName: String, serializer: String) {
        map.add(propName, serializer)
    }   

    public func hasAdaptor(propName: String): Bool {
        return map.contains(propName)
    }

    /*
    * Gets the json adaptor by identifier
    * @param identifier the identifier
    * @return JsonAdaptor the adaptor for given identifier
    */
    public func getAdaptor(propName: String): String {
        return map.get(propName)
        .getOrThrow({  => AdaptorMissingException("No adaptor registered for ${propName}") })
    }
}