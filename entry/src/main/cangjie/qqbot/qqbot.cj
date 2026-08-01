/**
 * Created on 2026/6/29
 */
package ohos_app_cangjie_entry.qqbot

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import linderHttp.*
import stdx.encoding.json.JsonObject
import stdx.encoding.json.JsonInt
import std.collection.ArrayList
import stdx.encoding.json.JsonArray
import stdx.encoding.json.JsonString
import ohos_app_cangjie_entry.run2JS
import ohos.base.AppLog
import stdx.encoding.url.URL


public var baseUrl: URL = URL.parse("http://39.96.218.120:8800")

@Interop[ArkTS]
public class QQbot {

    public func changeUrl(newUrl:String):Unit{
        baseUrl = URL.parse(newUrl)
    }

    public func getBotQQGroup(): Unit {
    }

    //获取共同群聊
    public func getCommonGroup(qqNum: String, returnFunc: (JSArrayEx<QQGroupInfoArk>) -> Unit,
        errorFunc: (String) -> Unit): Unit {
        spawn {
            let url = baseUrl.replace(path: "/check_group")
            try {
                let body = JsonObject()
                body.put("qqNumber", JsonString(qqNum))

                let res = HttpQuick
                    .post(url, body)
                    .getBodyJsonObject()

                let status = res
                    .get("status")
                    .getOrDefault({=> JsonString('error')})
                    .asString()
                    .getValue()
                if (status == "error") {
                    res
                        .get("message")
                        .getOrDefault({=> JsonString('error')})
                        .asString()
                        .getValue() |> errorFunc
                } else {
                    let groupNum = res
                        .get("common_count")
                        .getOrDefault({=> JsonInt(1)})
                        .asInt()
                        .getValue()

                    AppLog.info(res.toJsonString())

                    if (groupNum == 0) {
                        run2JS {
                            JSArrayEx<QQGroupInfoArk>([]) |> returnFunc
                        }
                    } else {
                        let resArray = ArrayList<QQGroupInfoArk>()
                        let groupNum = res
                            .get("common_groups")
                            .getOrDefault({=> JsonArray([])})
                            .asArray()
                            .getItems()
                        for (i in groupNum) {
                            let item = QQGroupInfoArk()
                            item.id = i
                                .asObject()
                                .get('group_id')
                                .getOrDefault({=> JsonString('')})
                                .asString()
                                .getValue()
                            item.name = i
                                .asObject()
                                .get('group_name')
                                .getOrDefault({=> JsonString('')})
                                .asString()
                                .getValue()
                            resArray.add(item)
                        }

                        run2JS {
                            JSArrayEx<QQGroupInfoArk>(resArray.toArray()) |> returnFunc
                        }
                    }
                }
            } catch (error: Exception) {
                run2JS {
                    "无法获取共有QQ群${error.message}" |> errorFunc
                }
            }
        }
    }

    public func getConfig(returnFunc: (BotConfig) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            let url = baseUrl.replace(path: "/notify_config")
            try {
                let res = HttpQuick
                    .get(url)
                    .getBodyJsonObject()
                let config = BotConfig.fromJson(res)
                run2JS {
                    config |> returnFunc
                }
            } catch (error: Exception) {
                run2JS {
                    "无法获取设置:${error.message}" |> errorFunc
                }
            }
        }
    }

//    @Interop[ArkTS, Invisible]
//    public static func send2QQ(body: JsonObject): String {
//        let url = baseUrl.replace(path: "/notify")
//        let clinet = LinderHttpClient()
//            .setUrl(url)
//            .setMethod(RequestMethod.POST)
//            .setBody(body)
//        let res = clinet.send()
//        res.getBodyJsonString()
//    }

    public QQbot() {}
}
