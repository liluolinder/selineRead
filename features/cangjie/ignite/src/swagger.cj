package ignite

import std.collection.{ArrayList, HashMap}
import std.unicode.*

public class RouteOption {
    public var summary: String = ""
    public var description: String = ""
    public var tags: ArrayList<String> = ArrayList<String>()
    public var deprecated: Bool = false
    public var operationId: String = ""
    public var consumes: ArrayList<String> = ArrayList<String>()
    public var produces: ArrayList<String> = ArrayList<String>()
    public var parameters: ArrayList<ParamSpec> = ArrayList<ParamSpec>()
    public var responses: ArrayList<ResponseSpec> = ArrayList<ResponseSpec>()
    public var security: ArrayList<String> = ArrayList<String>()
    public var hidden: Bool = false
    public var paramValidations: HashMap<String, String> = HashMap<String, String>()
    public var requestBody: ?RequestBodySpec = None
    public var testOption: ?TestOption = None

    public init() {}

    public func withParamValidation(name: String, pattern: String): RouteOption {
        paramValidations.add(name, pattern)
        this
    }

    public func withSummary(s: String): RouteOption {
        this.summary = s
        this
    }

    public func withDescription(d: String): RouteOption {
        this.description = d
        this
    }

    public func withTag(t: String): RouteOption {
        this.tags.add(t)
        this
    }

    public func withTags(ts: Array<String>): RouteOption {
        for (t in ts) {
            this.tags.add(t)
        }
        this
    }

    public func withDeprecated(d: Bool): RouteOption {
        this.deprecated = d
        this
    }

    public func withOperationId(id: String): RouteOption {
        this.operationId = id
        this
    }

    public func withParam(p: ParamSpec): RouteOption {
        this.parameters.add(p)
        this
    }

    public func withResponse(r: ResponseSpec): RouteOption {
        this.responses.add(r)
        this
    }

    public func withRequestBody(spec: RequestBodySpec): RouteOption {
        this.requestBody = spec
        this
    }

    public func withTestOption(opt: TestOption): RouteOption {
        this.testOption = opt
        this
    }

    public func withSecurity(s: String): RouteOption {
        this.security.add(s)
        this
    }

    public func asHidden(): RouteOption {
        this.hidden = true
        this
    }
}

public class RequestBodySpec {
    public var contentType: String = "application/json"
    public var schema: String = ""
    public var example: String = ""
    public var required: Bool = false

    public init() {}

    public init(
        contentType!: String = "application/json",
        schema!: String = "",
        example!: String = "",
        required!: Bool = false
    ) {
        this.contentType = contentType
        this.schema = schema
        this.example = example
        this.required = required
    }
}

public class TestOption {
    public var enabled: Bool = true
    public var mock: Bool = true
    public var probe: Bool = true
    public var storage: String = "memory"
    public var report: String = "inline"
    public var versionTag: String = "0500"
    public var mockBody: String = ""

    public init() {}

    public init(
        enabled!: Bool = true,
        mock!: Bool = true,
        probe!: Bool = true,
        storage!: String = "memory",
        report!: String = "inline",
        versionTag!: String = "0500",
        mockBody!: String = ""
    ) {
        this.enabled = enabled
        this.mock = mock
        this.probe = probe
        this.storage = storage
        this.report = report
        this.versionTag = versionTag
        this.mockBody = mockBody
    }

    public func withMockBody(body: String): TestOption {
        this.mockBody = body
        this
    }

    public func withVersionTag(tag: String): TestOption {
        this.versionTag = tag
        this
    }

    public func withStorage(kind: String): TestOption {
        this.storage = kind
        this
    }

    public func withReport(mode: String): TestOption {
        this.report = mode
        this
    }
}

public class InterfaceSpec {
    public var method: String
    public var path: String
    public var name: String = ""
    public var summary: String = ""
    public var description: String = ""
    public var tags: ArrayList<String> = ArrayList<String>()
    public var parameters: ArrayList<ParamSpec> = ArrayList<ParamSpec>()
    public var requestBody: ?RequestBodySpec = None
    public var responses: ArrayList<ResponseSpec> = ArrayList<ResponseSpec>()
    public var testOption: ?TestOption = None

    public init(method: String, path: String) {
        this.method = method
        this.path = path
    }
}

public enum ParamLocation {
    | Query
    | Header
    | Path
    | Cookie
}

public class ParamSpec {
    public var name: String
    public var location: ParamLocation
    public var description: String = ""
    public var required: Bool = false
    public var dataType: String = "string"
    public var example: String = ""

    public init(name: String, location: ParamLocation) {
        this.name = name
        this.location = location
    }

    public init(
        name: String,
        location: ParamLocation,
        description!: String = "",
        required!: Bool = false,
        dataType!: String = "string",
        example!: String = ""
    ) {
        this.name = name
        this.location = location
        this.description = description
        this.required = required
        this.dataType = dataType
        this.example = example
    }
}

public class ResponseSpec {
    public var statusCode: UInt16
    public var description: String = ""
    public var contentType: String = ""
    public var schema: String = ""
    public var example: String = ""

    public init(statusCode: UInt16) {
        this.statusCode = statusCode
    }

    public init(
        statusCode: UInt16,
        description!: String = "",
        contentType!: String = "",
        schema!: String = "",
        example!: String = ""
    ) {
        this.statusCode = statusCode
        this.description = description
        this.contentType = contentType
        this.schema = schema
        this.example = example
    }
}

public class SwaggerInfo {
    public var title: String = "Ignite API"
    public var description: String = ""
    public var version: String = "1.0.0"
    public var host: String = "localhost"
    public var basePath: String = "/"
    public var schemes: ArrayList<String> = ArrayList<String>()

    public init(title!: String = "Ignite API", description!: String = "", version!: String = "1.0.0") {
        this.title = title
        this.description = description
        this.version = version
        this.schemes.add("http")
    }
}

public class SwaggerGenerator {
    let info: SwaggerInfo
    let routes: ArrayList<Route>

    public init(info: SwaggerInfo, routes: ArrayList<Route>) {
        this.info = info
        this.routes = routes
    }

    public func generate(): String {
        var sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"openapi\": \"3.0.0\",\n")
        sb.append("  \"info\": {\n")
        sb.append("    \"title\": " + jsonStringLiteral(info.title) + ",\n")
        sb.append("    \"description\": " + jsonStringLiteral(info.description) + ",\n")
        sb.append("    \"version\": " + jsonStringLiteral(info.version) + "\n")
        sb.append("  },\n")
        sb.append("  \"paths\": {\n")

        let pathMap = HashMap<String, ArrayList<Route>>()
        for (route in routes) {
            if (let Some(opt) <- route.option) {
                if (opt.hidden) {
                    continue
                }
            }
            let swaggerPath = convertPath(route.path)
            if (!pathMap.contains(swaggerPath)) {
                pathMap.add(swaggerPath, ArrayList<Route>())
            }
            if (let Some(list) <- pathMap.get(swaggerPath)) {
                list.add(route)
            }
        }

        var pathIdx: Int64 = 0
        let pathCount = pathMap.size
        for ((path, pathRoutes) in pathMap) {
            sb.append("    \"${path}\": {\n")
            var routeIdx: Int64 = 0
            let routeCount = pathRoutes.size
            for (route in pathRoutes) {
                let methodLower = route.method.toLower()
                let opJson = buildOperationJson(route)
                sb.append("      \"${methodLower}\": {\n")
                sb.append(opJson)
                sb.append("      }")
                routeIdx += 1
                if (routeIdx < routeCount) {
                    sb.append(",")
                }
                sb.append("\n")
            }
            sb.append("    }")
            pathIdx += 1
            if (pathIdx < pathCount) {
                sb.append(",")
            }
            sb.append("\n")
        }

        sb.append("  }\n")
        sb.append("}")
        sb.toString()
    }

    func convertPath(path: String): String {
        var result = StringBuilder()
        var i: Int64 = 0
        let chars = path.toRuneArray()
        while (i < chars.size) {
            if (chars[i] == r':') {
                result.append(r'{')
                i += 1
                while (i < chars.size && chars[i] != r'/') {
                    result.append(chars[i])
                    i += 1
                }
                result.append(r'}')
            } else {
                result.append(chars[i])
                i += 1
            }
        }
        result.toString()
    }

    func paramLocationStr(loc: ParamLocation): String {
        match (loc) {
            case Query => "query"
            case Header => "header"
            case Path => "path"
            case Cookie => "cookie"
        }
    }
}

func buildInterfaceSpec(route: Route): InterfaceSpec {
    let spec = InterfaceSpec(route.method, route.path)
    let routeName = route.name.trimAscii()
    if (routeName.size > 0) {
        spec.name = routeName
    }

    match (route.option) {
        case Some(opt) =>
            spec.summary = opt.summary
            spec.description = opt.description
            spec.tags = cloneStringList(opt.tags)
            spec.parameters = cloneParamSpecs(opt.parameters)
            spec.responses = cloneResponseSpecs(opt.responses)
            match (opt.requestBody) {
                case Some(body) => spec.requestBody = Some(cloneRequestBodySpec(body))
                case None => ()
            }
            match (opt.testOption) {
                case Some(testOpt) => spec.testOption = Some(cloneTestOption(testOpt))
                case None => ()
            }
            if (spec.name.size == 0) {
                let opId = opt.operationId.trimAscii()
                if (opId.size > 0) {
                    spec.name = opId
                }
            }
        case None => ()
    }
    spec
}

func buildOperationJson(route: Route): String {
    let spec = buildInterfaceSpec(route)
    let fields = ArrayList<String>()

    if (spec.summary.size > 0) {
        fields.add("        \"summary\": " + jsonStringLiteral(spec.summary))
    }
    if (spec.description.size > 0) {
        fields.add("        \"description\": " + jsonStringLiteral(spec.description))
    }
    if (spec.tags.size > 0) {
        fields.add(buildTagsJson(spec.tags))
    }
    if (spec.name.size > 0) {
        fields.add("        \"operationId\": " + jsonStringLiteral(spec.name))
    }
    match (route.option) {
        case Some(opt) =>
            if (opt.deprecated) {
                fields.add("        \"deprecated\": true")
            }
        case None => ()
    }

    let parametersJson = buildParametersJson(spec.parameters)
    if (parametersJson.size > 0) {
        fields.add(parametersJson)
    }

    let requestBodyJson = buildRequestBodyJson(spec.requestBody)
    if (requestBodyJson.size > 0) {
        fields.add(requestBodyJson)
    }

    let testJson = buildTestOptionJson(spec.testOption)
    if (testJson.size > 0) {
        fields.add(testJson)
    }

    if (spec.responses.size > 0) {
        fields.add(buildResponsesJson(spec.responses))
    } else {
        fields.add("        \"responses\": { \"200\": { \"description\": \"OK\" } }")
    }

    joinJsonFields(fields)
}

func buildTagsJson(tags: ArrayList<String>): String {
    var sb = StringBuilder()
    sb.append("        \"tags\": [")
    for (i in 0..tags.size) {
        sb.append(jsonStringLiteral(tags[i]))
        if (i < tags.size - 1) {
            sb.append(", ")
        }
    }
    sb.append("]")
    sb.toString()
}

func buildParametersJson(parameters: ArrayList<ParamSpec>): String {
    if (parameters.size == 0) {
        return ""
    }
    var sb = StringBuilder()
    sb.append("        \"parameters\": [\n")
    for (i in 0..parameters.size) {
        let p = parameters[i]
        let fields = ArrayList<String>()
        fields.add("            \"name\": " + jsonStringLiteral(p.name))
        fields.add("            \"in\": " + jsonStringLiteral(paramLocationToString(p.location)))
        fields.add("            \"description\": " + jsonStringLiteral(p.description))
        fields.add("            \"required\": ${p.required}")
        fields.add("            \"schema\": { \"type\": " + jsonStringLiteral(p.dataType) + " }")
        if (p.example.size > 0) {
            fields.add("            \"example\": " + jsonStringLiteral(p.example))
        }

        sb.append("          {\n")
        sb.append(joinJsonFields(fields))
        sb.append("          }")
        if (i < parameters.size - 1) {
            sb.append(",")
        }
        sb.append("\n")
    }
    sb.append("        ]")
    sb.toString()
}

func buildRequestBodyJson(spec: ?RequestBodySpec): String {
    match (spec) {
        case Some(bodySpec) =>
            let mediaType = if (bodySpec.contentType.trimAscii().size > 0) {
                bodySpec.contentType
            } else {
                "application/json"
            }
            let mediaFields = ArrayList<String>()
            if (bodySpec.schema.trimAscii().size > 0) {
                mediaFields.add("              \"schema\": " + bodySpec.schema)
            }
            if (bodySpec.example.trimAscii().size > 0) {
                mediaFields.add("              \"example\": " + bodySpec.example)
            }
            if (mediaFields.size == 0) {
                mediaFields.add("              \"schema\": {}")
            }

            let bodyFields = ArrayList<String>()
            bodyFields.add("          \"required\": ${bodySpec.required}")
            bodyFields.add(
                "          \"content\": {\n" +
                "            " + jsonStringLiteral(mediaType) + ": {\n" +
                joinJsonFields(mediaFields) +
                "            }\n" +
                "          }"
            )

            return "        \"requestBody\": {\n" +
                joinJsonFields(bodyFields) +
                "        }"
        case None => ""
    }
}

func buildResponsesJson(responses: ArrayList<ResponseSpec>): String {
    var sb = StringBuilder()
    sb.append("        \"responses\": {\n")
    for (i in 0..responses.size) {
        let r = responses[i]
        let responseFields = ArrayList<String>()
        responseFields.add("            \"description\": " + jsonStringLiteral(r.description))

        let hasContent =
            r.contentType.trimAscii().size > 0 ||
            r.schema.trimAscii().size > 0 ||
            r.example.trimAscii().size > 0
        if (hasContent) {
            let mediaType = if (r.contentType.trimAscii().size > 0) {
                r.contentType
            } else {
                "application/json"
            }
            let mediaFields = ArrayList<String>()
            if (r.schema.trimAscii().size > 0) {
                mediaFields.add("                \"schema\": " + r.schema)
            }
            if (r.example.trimAscii().size > 0) {
                mediaFields.add("                \"example\": " + r.example)
            }
            if (mediaFields.size == 0) {
                mediaFields.add("                \"schema\": {}")
            }
            responseFields.add(
                "            \"content\": {\n" +
                "              " + jsonStringLiteral(mediaType) + ": {\n" +
                joinJsonFields(mediaFields) +
                "              }\n" +
                "            }"
            )
        }

        sb.append("          " + jsonStringLiteral("${r.statusCode}") + ": {\n")
        sb.append(joinJsonFields(responseFields))
        sb.append("          }")
        if (i < responses.size - 1) {
            sb.append(",")
        }
        sb.append("\n")
    }
    sb.append("        }")
    sb.toString()
}

func buildTestOptionJson(spec: ?TestOption): String {
    match (spec) {
        case Some(opt) =>
            let fields = ArrayList<String>()
            fields.add("          \"enabled\": ${opt.enabled}")
            fields.add("          \"mock\": ${opt.mock}")
            fields.add("          \"probe\": ${opt.probe}")
            fields.add("          \"storage\": " + jsonStringLiteral(opt.storage))
            fields.add("          \"report\": " + jsonStringLiteral(opt.report))
            fields.add("          \"versionTag\": " + jsonStringLiteral(opt.versionTag))
            return "        \"x-ignite-test\": {\n" +
                joinJsonFields(fields) +
                "        }"
        case None => ""
    }
}

func paramLocationToString(loc: ParamLocation): String {
    match (loc) {
        case Query => "query"
        case Header => "header"
        case Path => "path"
        case Cookie => "cookie"
    }
}

func joinJsonFields(fields: ArrayList<String>): String {
    var sb = StringBuilder()
    for (i in 0..fields.size) {
        sb.append(fields[i])
        if (i < fields.size - 1) {
            sb.append(",")
        }
        sb.append("\n")
    }
    sb.toString()
}

func cloneStringList(source: ArrayList<String>): ArrayList<String> {
    let out = ArrayList<String>()
    for (item in source) {
        out.add(item)
    }
    out
}

func cloneParamSpecs(source: ArrayList<ParamSpec>): ArrayList<ParamSpec> {
    let out = ArrayList<ParamSpec>()
    for (item in source) {
        out.add(ParamSpec(
            item.name,
            item.location,
            description: item.description,
            required: item.required,
            dataType: item.dataType,
            example: item.example
        ))
    }
    out
}

func cloneResponseSpecs(source: ArrayList<ResponseSpec>): ArrayList<ResponseSpec> {
    let out = ArrayList<ResponseSpec>()
    for (item in source) {
        out.add(ResponseSpec(
            item.statusCode,
            description: item.description,
            contentType: item.contentType,
            schema: item.schema,
            example: item.example
        ))
    }
    out
}

func cloneRequestBodySpec(source: RequestBodySpec): RequestBodySpec {
    RequestBodySpec(
        contentType: source.contentType,
        schema: source.schema,
        example: source.example,
        required: source.required
    )
}

func cloneTestOption(source: TestOption): TestOption {
    TestOption(
        enabled: source.enabled,
        mock: source.mock,
        probe: source.probe,
        storage: source.storage,
        report: source.report,
        versionTag: source.versionTag,
        mockBody: source.mockBody
    )
}

func jsonStringLiteral(value: String): String {
    "\"" + escapeJsonString(value) + "\""
}

func escapeJsonString(value: String): String {
    escapeJsonText(value)
}

class StringBuilder {
    var data: ArrayList<String> = ArrayList<String>()

    func append(s: String): Unit {
        data.add(s)
    }

    func append(r: Rune): Unit {
        data.add(r.toString())
    }

    func toString(): String {
        var result = ""
        for (s in data) {
            result += s
        }
        result
    }
}
