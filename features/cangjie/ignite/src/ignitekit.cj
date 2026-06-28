package ignite

import std.collection.ArrayList

/// IgniteKit: 轻量资源编排器。用于把动态生成的 HTML/CSS/文本快速挂到 Ignite 路由上，
/// 适合把页面模板与服务逻辑从业务主路由中剥离，减少主 app 文件臃肿度。
public type IgniteKitRenderer = (Ctx) -> String

public class IgniteKitAsset {
    public let path: String
    public let contentType: String
    let _staticBody: ?String
    let _renderer: ?IgniteKitRenderer

    public init(
        path: String,
        contentType: String,
        staticBody!: ?String = None,
        renderer!: ?IgniteKitRenderer = None
    ) {
        this.path = normalizeKitPath(path, "/")
        this.contentType = normalizeContentType(contentType)
        this._staticBody = staticBody
        this._renderer = renderer
    }

    public func render(ctx: Ctx): String {
        if (let Some(renderer) <- _renderer) {
            return renderer(ctx)
        }
        _staticBody ?? ""
    }
}

public class IgniteKit {
    public let prefix: String
    var _assets: ArrayList<IgniteKitAsset> = ArrayList<IgniteKitAsset>()

    public init(prefix!: String = "/kit") {
        this.prefix = normalizeKitPrefix(prefix)
    }

    /// 注册纯文本资源（可用于 JS/CSS/JSON/HTML）
    public func asset(path: String, contentType: String, body: String): IgniteKit {
        _assets.add(IgniteKitAsset(path, contentType, staticBody: body))
        this
    }

    /// 注册静态 HTML（支持 {{key}} 模板替换）
    public func html(
        path: String,
        template: String,
        vars!: Array<(String, String)> = []
    ): IgniteKit {
        asset(path, "text/html; charset=utf-8", renderTemplate(template, vars: vars))
    }

    /// 注册静态 CSS
    public func css(path: String, body: String): IgniteKit {
        asset(path, "text/css; charset=utf-8", body)
    }

    /// 注册动态资源（每次请求实时渲染）
    public func dynamic(path: String, contentType: String, renderer: IgniteKitRenderer): IgniteKit {
        _assets.add(IgniteKitAsset(path, contentType, renderer: renderer))
        this
    }

    /// 注册动态 HTML
    public func dynamicHtml(path: String, renderer: IgniteKitRenderer): IgniteKit {
        dynamic(path, "text/html; charset=utf-8", renderer)
    }

    /// 将 IgniteKit 资源批量挂载到 App 路由
    public func mount(app: App): App {
        for (asset in _assets) {
            registerKitRoute(app, prefix, asset)
        }
        app
    }

    /// 计算资源最终路由（用于在模板中生成引用链接）
    public func routePath(path: String): String {
        joinKitRoute(prefix, normalizeKitPath(path, "/"))
    }

    public func assets(): Array<IgniteKitAsset> {
        _assets.toArray()
    }

    /// 简单模板渲染：将 `{{key}}` 替换成对应 value
    public func renderTemplate(template: String, vars!: Array<(String, String)> = []): String {
        var output = template
        for ((key, value) in vars) {
            output = replaceAllText(output, "{{${key}}}", value)
        }
        output
    }
}

func registerKitRoute(app: App, prefix: String, asset: IgniteKitAsset): Unit {
    let routePath = joinKitRoute(prefix, asset.path)
    let contentType = asset.contentType
    app.get(routePath, { ctx =>
        _ = ctx.setHeader("content-type", contentType).sendString(asset.render(ctx))
    })
}

func normalizeKitPrefix(raw: String): String {
    let trimmed = raw.trimAscii()
    if (trimmed.size == 0 || trimmed == "/") {
        return ""
    }
    var prefix = trimmed
    if (!kitStartsWithSlash(prefix)) {
        prefix = "/" + prefix
    }
    prefix = trimTrailingSlash(prefix)
    if (prefix == "/") {
        return ""
    }
    prefix
}

func normalizeKitPath(raw: String, fallback: String): String {
    let trimmed = raw.trimAscii()
    if (trimmed.size == 0) {
        return fallback
    }
    var path = trimmed
    if (!kitStartsWithSlash(path)) {
        path = "/" + path
    }
    if (path.size > 1) {
        path = trimTrailingSlash(path)
    }
    if (path.size == 0) {
        return fallback
    }
    path
}

func normalizeContentType(raw: String): String {
    let trimmed = raw.trimAscii()
    if (trimmed.size == 0) {
        return "text/plain; charset=utf-8"
    }
    trimmed
}

func joinKitRoute(prefix: String, path: String): String {
    if (prefix.size == 0) {
        return path
    }
    if (path == "/") {
        return prefix
    }
    prefix + path
}

func kitStartsWithSlash(text: String): Bool {
    let runes = text.toRuneArray()
    if (runes.size == 0) {
        return false
    }
    runes[0] == r'/'
}

func trimTrailingSlash(text: String): String {
    let runes = text.toRuneArray()
    if (runes.size <= 1) {
        return text
    }
    var end = runes.size
    while (end > 1 && runes[end - 1] == r'/') {
        end -= 1
    }
    var out = ""
    for (i in 0..end) {
        out += runes[i].toString()
    }
    out
}

func replaceAllText(input: String, needle: String, replacement: String): String {
    if (needle.size == 0) {
        return input
    }
    let chunks = input.split(needle)
    if (chunks.size <= 1) {
        return input
    }
    var out = ""
    for (i in 0..chunks.size) {
        if (i > 0) {
            out += replacement
        }
        out += chunks[i]
    }
    out
}
