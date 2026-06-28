package ignite.middleware

import ignite.{Handler, Ctx}
import std.fs.{File, OpenMode}
import std.collection.ArrayList

public class FaviconConfig {
    public var file: String = ""
    public var cacheControl: String = "public, max-age=31536000"

    public init(file!: String = "", cacheControl!: String = "public, max-age=31536000") {
        this.file = file
        this.cacheControl = cacheControl
    }
}

public func faviconMiddleware(config!: FaviconConfig = FaviconConfig()): Handler {
    var iconData: ?Array<UInt8> = None

    if (config.file.size > 0) {
        try {
            let f = File(config.file, OpenMode.Read)
            let buf = ArrayList<UInt8>()
            let tmp = Array<UInt8>(8192, repeat: 0)
            while (true) {
                let n = f.read(tmp)
                if (n <= 0) { break }
                for (i in 0..n) {
                    buf.add(tmp[i])
                }
            }
            f.close()
            iconData = buf.toArray()
        } catch (_: Exception) {}
    }

    let cachedIcon = iconData

    { ctx: Ctx =>
        if (ctx.path != "/favicon.ico") {
            ctx.next()
            return
        }

        if (ctx.method != "GET" && ctx.method != "HEAD") {
            if (ctx.method != "OPTIONS") {
                ctx.status(405).sendString("Method Not Allowed")
            } else {
                ctx.sendStatus(204)
            }
            return
        }

        ctx.setHeader("Cache-Control", config.cacheControl)

        if (let Some(data) <- cachedIcon) {
            ctx.setHeader("content-type", "image/x-icon")
            ctx.send(data)
        } else {
            ctx.sendStatus(204)
        }
    }
}
