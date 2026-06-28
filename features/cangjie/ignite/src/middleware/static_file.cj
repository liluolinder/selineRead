package ignite.middleware

import ignite.{Handler, Ctx, resolveStaticAssetPath}

public class StaticFileConfig {
    public var root: String = "./public"
    public var index: String = "index.html"
    public var browse: Bool = false
    public var maxAge: Int64 = 0

    public init(
        root!: String = "./public",
        index!: String = "index.html",
        browse!: Bool = false,
        maxAge!: Int64 = 0
    ) {
        this.root = root
        this.index = index
        this.browse = browse
        this.maxAge = maxAge
    }
}

public func staticFileMiddleware(config!: StaticFileConfig = StaticFileConfig()): Handler {
    { ctx: Ctx =>
        if (ctx.method != "GET" && ctx.method != "HEAD") {
            ctx.next()
            return
        }

        let filePathOpt = if (ctx.path == "/" || ctx.path.size == 0) {
            resolveStaticAssetPath(config.root, config.index)
        } else {
            resolveStaticAssetPath(config.root, ctx.path)
        }
        if (let None <- filePathOpt) {
            ctx.next()
            return
        }
        let filePath = match (filePathOpt) {
            case Some(path) => path
            case None => ""
        }

        if (config.maxAge > 0) {
            ctx.setHeader("Cache-Control", "public, max-age=${config.maxAge}")
        }

        try {
            ctx.sendFile(filePath)
        } catch (_: Exception) {
            ctx.next()
        }
    }
}
