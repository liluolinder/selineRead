/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A node.
 */
public class DocumentType <: LeafNode {
    public static let PUBLIC_KEY: String = "PUBLIC"

    public static let SYSTEM_KEY: String = "SYSTEM"

    private static let NAME: String = "name"

    // PUBLIC or SYSTEM
    private static let PUB_SYS_KEY: String = "pubSysKey"

    private static let PUBLIC_ID: String = "publicId"

    private static let SYSTEM_ID: String = "systemId"

    protected var publicIdValue: String = ""

    protected var systemIdValue: String = ""

    /*
     * Create a new doctype element.
     *
     * @param name the doctype's name
     * @param publicId the doctype's public ID
     * @param systemId the doctype's system ID
     */
    public init(name: String, publicId: String, systemId: String) {
        super(name)
        this.publicIdValue = publicId
        this.systemIdValue = systemId
        attr(NAME, name)
        attr(PUBLIC_ID, publicId)
        attr(SYSTEM_ID, systemId)
        updatePubSyskey()
    }

    public func setPubSysKey(value: ?String): Unit {
        if (value != None) {
            attr(PUB_SYS_KEY, value())
        }
    }

    private func updatePubSyskey(): Unit {
        if (has(PUBLIC_ID)) {
            attr(PUB_SYS_KEY, PUBLIC_KEY)
        } else if (has(SYSTEM_ID)) {
            attr(PUB_SYS_KEY, SYSTEM_KEY)
        }
    }

    /*
     * Get this doctype's name (when set, or empty string)
     *
     * @return doctype name
     */
    public func name(): String {
        return attr(NAME)
    }

    /*
     * Get this doctype's Public ID (when set, or empty string)
     *
     * @return doctype Public ID
     */
    public func publicId(): String {
        return attr(PUBLIC_ID)
    }

    /*
     * Get this doctype's System ID (when set, or empty string)
     *
     * @return doctype System ID
     */
    public func systemId(): String {
        return attr(SYSTEM_ID)
    }

    public override func nodeName(): String {
        return "#doctype"
    }

    protected override func outerHtmlHead(
        stringBuilder: StringBuilder,
        _: Int64,
        documentOutputSettings: DocumentOutputSettings
    ): Unit {
        // add a newline if the doctype has a preceding node (which must be a comment)
        if (siblingIndexInt > 0 && documentOutputSettings.prettyPrint()) {
            stringBuilder.append(r'\n')
        }
        var doAppend: Bool = false
        if (documentOutputSettings.syntax() == Syntax.htmlSyntax) {
            if (!has(PUBLIC_ID)) {
                if (!has(SYSTEM_ID)) {
                    doAppend = true
                }
            }
        }
        if (doAppend) {
            // looks like a html5 doctype, go lowercase for aesthetics
            stringBuilder.append("<!doctype")
        } else {
            stringBuilder.append("<!DOCTYPE")
        }
        if (has(NAME)) {
            stringBuilder.append(" ")
            stringBuilder.append(attr(NAME))
        }
        if (has(PUB_SYS_KEY)) {
            stringBuilder.append(" ")
            stringBuilder.append(attr(PUB_SYS_KEY))
        }
        if (has(PUBLIC_ID)) {
            stringBuilder.append(" \"")
            stringBuilder.append(attr(PUBLIC_ID))
            stringBuilder.append(r'"')
        }
        if (has(SYSTEM_ID)) {
            stringBuilder.append(" \"")
            stringBuilder.append(attr(SYSTEM_ID))
            stringBuilder.append(r'"')
        }
        stringBuilder.append(r'>')
    }

    protected override func outerHtmlTail(_: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {}

    private func has(attribute: String): Bool {
        return !StringUtil.isBlank(attr(attribute))
    }
}
