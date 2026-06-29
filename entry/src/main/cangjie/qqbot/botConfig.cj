/**
 * Created on 2026/6/30
 */
package ohos_app_cangjie_entry.qqbot

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import stdx.encoding.json.JsonObject

@Interop[ArkTS]
public class BotConfig{

    public var canPush2QQ:Bool = false

    @Interop[ArkTS, Invisible]
    public static func fromJson(jsonObj:JsonObject):BotConfig{
        let value = BotConfig()
        if (let Some(_canPush2QQ)<-jsonObj.get('push_to_qq')){
            value.canPush2QQ = _canPush2QQ.asBool().getValue()
        }
        value
    }

    public BotConfig(){}
}