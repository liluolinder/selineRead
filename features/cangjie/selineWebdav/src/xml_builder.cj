package selineWebdav

import std.time.DateTime
import std.collection.ArrayList
import stdx.encoding.url.*

// WebDAV XML响应生成器
public class XmlBuilder {
    public var content: String = ""
    private let indentStr: String = "  "
    public var indentLevel: Int64 = 0

    public init() {}

    // 开始XML文档
    public func startDocument(): XmlBuilder {
        content = #"<?xml version="1.0" encoding="utf-8" ?>"# + "\n"
        this
    }

    // 开始元素
    public func startElement(name: String): XmlBuilder {
        addIndent()
        content += "<${name}>\n"
        indentLevel += 1
        this
    }

    // 开始带命名空间的元素
    public func startElementNS(prefix: String, name: String): XmlBuilder {
        addIndent()
        content += "<${prefix}:${name}>\n"
        indentLevel += 1
        this
    }

    // 结束元素
    public func endElement(name: String): XmlBuilder {
        indentLevel -= 1
        addIndent()
        content += "</${name}>\n"
        this
    }

    // 结束带命名空间的元素
    public func endElementNS(prefix: String, name: String): XmlBuilder {
        indentLevel -= 1
        addIndent()
        content += "</${prefix}:${name}>\n"
        this
    }

    // 添加元素和文本内容
    public func element(name: String, text: String): XmlBuilder {
        addIndent()
        content += "<${name}>${escapeXml(text)}</${name}>\n"
        this
    }

    // 添加带命名空间的元素和文本内容
    public func elementNS(prefix: String, name: String, text: String): XmlBuilder {
        addIndent()
        content += "<${prefix}:${name}>${escapeXml(text)}</${prefix}:${name}>\n"
        this
    }

    // 添加空元素
    public func emptyElement(name: String): XmlBuilder {
        addIndent()
        content += "<${name}/>\n"
        this
    }

    // 添加带命名空间的空元素
    public func emptyElementNS(prefix: String, name: String): XmlBuilder {
        addIndent()
        content += "<${prefix}:${name}/>\n"
        this
    }

    // 添加属性
    public func attribute(name: String, value: String): XmlBuilder {
        // 移除最后的换行符和>
        if (content.endsWith(">\n")) {
            content = content[0..(content.size - 2)]
            content += " ${name}=\"${escapeXml(value)}\">\n"
        }
        this
    }

    // 添加原始文本
    public func raw(text: String): XmlBuilder {
        content += text
        this
    }

    // 构建最终字符串
    public func build(): String {
        content
    }

    // 添加缩进
    private func addIndent(): Unit {
        for (_ in 0..indentLevel) {
            content += indentStr
        }
    }

    // XML转义
    private func escapeXml(s: String): String {
        var result = ""
        for (ch in s.toRuneArray()) {
            match (ch) {
                case r'<' => result += "&lt;"
                case r'>' => result += "&gt;"
                case r'&' => result += "&amp;"
                case r'"' => result += "&quot;"
                case r'\'' => result += "&apos;"
                case _ => result += ch.toString()
            }
        }
        result
    }
}

// WebDAV多状态响应生成器
public class MultiStatusBuilder {
    private let xml: XmlBuilder
    private let baseUrl: String
    private let encodeHref: Bool

    public init(baseUrl: String, encodeHref!: Bool = false) {
        this.xml = XmlBuilder()
        this.baseUrl = baseUrl
        this.encodeHref = encodeHref
    }

    // 开始多状态响应
    public func start(): MultiStatusBuilder {
        xml.startDocument().raw("<D:multistatus xmlns:D=\"DAV:\">\n")
        xml.indentLevel = 1
        this
    }

    // 添加响应项
    public func addResponse(href: String, status: String, propStats: ArrayList<PropStat>): MultiStatusBuilder {
        xml.startElement("D:response").element("D:href", makeHref(href)).startElement("D:propstat")

        // 添加属性
        xml.startElement("D:prop")
        for (ps in propStats) {
            if (ps.hasValue) {
                if (ps.name == "resourcetype") {
                    // resourcetype 特殊处理：支持原始 XML 内容
                    if (ps.value.size > 0) {
                        // 目录: <D:resourcetype><D:collection/></D:resourcetype>
                        // 手动添加缩进和内容
                        var indent = ""
                        for (_ in 0..xml.indentLevel) {
                            indent += "  "
                        }
                        xml.content += "${indent}<D:resourcetype>${ps.value}</D:resourcetype>\n"
                    } else {
                        // 文件: <D:resourcetype/>
                        xml.emptyElementNS("D", ps.name)
                    }
                } else if (ps.value.size > 0) {
                    xml.elementNS("D", ps.name, ps.value)
                } else {
                    xml.emptyElementNS("D", ps.name)
                }
            }
        }
        xml.endElement("D:prop")

        // 添加状态
        xml.element("D:status", status).endElement("D:propstat").endElement("D:response")
        this
    }

    // 添加文件/目录信息响应
    public func addFileResponse(fileInfo: WebDavFileInfo, _depth: Int64): MultiStatusBuilder {
        let href = makeHref(fileInfo.path)
        let propStats = ArrayList<PropStat>()

        // 添加资源类型
        let resType = PropStat("resourcetype", "", true)
        if (fileInfo.isDirectory) {
            resType.value = "<D:collection/>"
        }
        propStats.add(resType)

        // 添加显示名称
        propStats.add(PropStat("displayname", fileInfo.name, true))

        // 掷取最后修改时间
        propStats.add(PropStat("getlastmodified", formatDateTime(fileInfo.modifiedTime), true))

        // 添加内容长度(仅文件)
        if (!fileInfo.isDirectory) {
            propStats.add(PropStat("getcontentlength", "${fileInfo.size}", true))
        }

        // 添加创建时间
        propStats.add(PropStat("creationdate", formatDateTime(fileInfo.createdTime), true))

        addResponse(href, "HTTP/1.1 200 OK", propStats)
        this
    }

    // 结束多状态响应
    public func end(): MultiStatusBuilder {
        xml.raw("</D:multistatus>")
        this
    }

    // 构建最终字符串
    public func build(): String {
        xml.build()
    }

    // 生成href
    private func makeHref(path: String): String {
        // path 已经是相对于根目录的路径
        var relativePath = path

        // 处理Windows路径分隔符
        relativePath = relativePath.replace("\\", "/")

        // 移除开头的斜杠
        while (relativePath.size > 0 && relativePath.startsWith("/")) {
            relativePath = relativePath[1..]
        }

        // 确保以/开头
        let href = if (relativePath.size == 0) {
            "/"
        } else {
            "/" + relativePath
        }

        // 根据配置决定是否URL编码
        // if (encodeHref) {
        //     URL.encode(href)
        // } else {
        //     href
        // }
         href
    }

    // 格式化日期时间
    private func formatDateTime(dt: DateTime): String {
        // RFC 1123格式: Wed, 21 Oct 2015 07:28:00 GMT
        // 简化实现，实际需要根据DateTime API调整
        dt.toString()
    }
}

// 属性状态
public class PropStat {
    public let name: String
    public var value: String
    public let hasValue: Bool

    public init(name: String, value: String, hasValue: Bool) {
        this.name = name
        this.value = value
        this.hasValue = hasValue
    }
}
