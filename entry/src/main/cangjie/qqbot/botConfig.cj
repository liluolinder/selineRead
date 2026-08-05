/**
 * Created on 2026/6/30
 */
package ohos_app_cangjie_entry.qqbot

import ohos.ark_interop_advance.*
import ohos.ark_interop_macro.*
import stdx.encoding.json.JsonObject

@Interop[ArkTS]
public class BotConfig{

    public var canPush2QQ:Bool = false
    public var status:String = "error"
    public var message:Option<String> = None

    @Interop[ArkTS, Invisible]
    public static func fromJson(jsonObj:JsonObject):BotConfig{
        let value = BotConfig()
        if (let Some(_canPush2QQ)<-jsonObj.get('push_to_qq')){
            value.canPush2QQ = _canPush2QQ.asBool().getValue()
        }

         if (let Some(_status)<-jsonObj.get('status')){
            value.status = _status.asString().getValue()
         }

         if (let Some(_message)<-jsonObj.get('message')){
            value.message = _message.asString().getValue()
         }


        value
    }

    public BotConfig(){}
}