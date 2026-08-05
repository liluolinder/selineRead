/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

public class PseudoTextElement <: Element {
    public init(tag: Tag, baseUri: String, attributes: Attributes) {
        super(tag, baseUri, attributes)
    }

    protected override func outerHtmlHead(_: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {}

    protected override func outerHtmlTail(_: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {}
}
