/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A HTML Form Element provides ready access to the form fields/controls that are associated with it. It also allows a form to easily be submitted.
 */
public class FormElement <: Element {
    private var elementArr: Elements = Elements()

    /*
     * Create a new, standalone form element.
     *
     * @param tag        tag of this element
     * @param baseUri    the base URI
     * @param attributes initial attributes
     */
    public init(tag: Tag, baseUri: ?String, attributes: ?Attributes) {
        super(tag, baseUri, attributes)
    }

    /*
     * Get the list of form control elements associated with this form.
     *
     * @return form controls associated with this element.
     */
    public func elements(): Elements {
        return elementArr
    }

    /*
     * Add a form control element to this form.
     *
     * @param element form control to add
     * @return this form element, for chaining
     */
    public func addElement(element: Element): FormElement {
        elementArr.elementArr.add(element)
        return this
    }

    protected override func removeChild(out: Node): Unit {
        super.removeChild(out)
        for (i in 0..elementArr.elementArr.size) {
            if (elementArr.elementArr.get(i)() == ((out as Element)())) {
                elementArr.elementArr.remove(at: i)
                break
            }
        }
    }

    public override func clone(): FormElement {
        var formElement: FormElement = (super.clone() as FormElement)()
        formElement.elementArr = this.elementArr
        return formElement
    }
}
