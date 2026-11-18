@NonProduct
features {}
package ohos_app_cangjie_entry.model

import std.collection.HashMap
import stdx.serialization.serialization.*
import stdx.encoding.json.*
import CJson.*
import kit.UIKit.*

public interface INavPathStackExt {
    func pushPath(path: String): Unit
    func pushPath(path: String, param: String): Unit
    func pushPath<K, V>(path: String,
        
        param: HashMap<K,
            V>): Unit where K <: Hashable & Equatable<K> & Serializable<K>,
        V <: Hashable & Equatable<V> & Serializable<V>
    //下面需要添加CJson库
    func pushPath<T>(path: String, param: T): Unit where T <: IJsonSerializable<T>
}

extend NavPathStack <: INavPathStackExt {
    public func pushPath(path: String) {
        this.pushPath(NavPathInfo(path, ""))
    }

    public func pushPath(path: String, param: String) {
        this.pushPath(NavPathInfo(path, param))
    }

    public func pushPath<K, V>(path: String,
        
        param: HashMap<K,
            V>): Unit where K <: Hashable & Equatable<K> & Serializable<K>,
        V <: Hashable & Equatable<V> & Serializable<V> {
        this.pushPath(path, param.serialize().toJson().toString())
    }
    //下面需要添加CJson库
    public func pushPath<T>(path: String, param: T): Unit where T <: IJsonSerializable<T> {
        this.pushPath(path, param.toJson().toString())
    }
}

public interface INavDesCtxExt {
    func getParamAsHashMap<K,
        V>(): HashMap<K,
        V> where K <: Hashable & Equatable<K> & Serializable<K>, V <: Hashable & Equatable<V> & Serializable<V>
    //下面需要添加CJson库
    func getParamByCjson<T>(): T where T <: IJsonSerializable<T>

    prop param: String
}

// extend NavDestinationContext <: INavDesCtxExt {
//     public prop param: String {
//         get() {
//             this.pathStack.getParamByName(this.pathInfo.name)[0]
//         }
//     }

//     public func getParamAsHashMap<K,
//         V>(): HashMap<K,
//         V> where K <: Hashable & Equatable<K> & Serializable<K>, V <: Hashable & Equatable<V> & Serializable<V> {
//         param |> JsonValue.fromStr |> DataModel.fromJson |> HashMap<K, V>.deserialize
//     }

//     //下面需要添加CJson库
//     public func getParamByCjson<T>(): T where T <: IJsonSerializable<T> {
//         param |> JsonValue.fromStr |> T.fromJsonValue
//     }
// }
