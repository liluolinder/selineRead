/**
 * Created on 2026/3/12
 */
package ohos_app_cangjie_entry.webdav

import ohos.ark_interop_macro.*
import ohos.ark_interop_advance.*
import selineWebdav.WebDavServer
import ohos.hilog.Hilog
import std.collection.ArrayList
import selineWebdav.WebDavUser
import selineWebdav.WebDavConfig


@Interop[ArkTS]
public class webdavArk {
    var webdavServer: Option<WebDavServer> = None

    public func start(): Unit {
        if (let Some(server) <- webdavServer) {
            spawn {
                Hilog.info(114514, 'webdav', '启动服务器')
                server.start()
            }
        }
    }

    public func stop(): Unit {
        if (let Some(server) <- webdavServer) {
            spawn {
                Hilog.info(114514, 'webdav', '关闭服务器')
                server.shutdown()
            }
        }
    }

    public webdavArk(rootPath: String, port: Int64, account: String, password: String) {
        let users = ArrayList<WebDavUser>()
        users.add(WebDavUser(account, password))
        let handlerConfig = WebDavConfig(
            rootPath,
            enableAuth: true,
            users: users,
            encodeHref: false
        )
        webdavServer = WebDavServer(handlerConfig, host: '0.0.0.0', port: port)
    }
}
