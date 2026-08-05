/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * @file The file declars the LinkedList class.
 */
class LinkedListNode<T> {
    LinkedListNode(var prev!: ?LinkedListNode<T>, var value!: T, var next!: ?LinkedListNode<T>) {}
}

class LinkedList<T> <: Collection<T> {
    private var mySize: Int64 = 0

    private var first: ?LinkedListNode<T> = None

    private var last: ?LinkedListNode<T> = None

    public init() {}

    public prop size: Int64 {
        get() {
            return this.mySize
        }
    }

    public func clear(): Unit {
        this.mySize = 0
        this.first = None
        this.last = None
    }

    public func isEmpty(): Bool {
        this.mySize == 0
    }

    public func iterator(): Iterator<T> {
        LinkedListIterator(this.first)
    }

    public func getFirst(): T {
        return match (this.first) {
            case Some(v) => v.value
            case _ => throw IndexOutOfBoundsException()
        }
    }

    public func getLast(): T {
        return match (this.last) {
            case Some(v) => v.value
            case _ => throw IndexOutOfBoundsException()
        }
    }

    public func get(index: Int64): T {
        if (index < 0 || index >= this.mySize) {
            throw IndexOutOfBoundsException()
        }
        match (at(index)) {
            case Some(v) => v.value
            case _ => throw IndexOutOfBoundsException()
        }
    }

    public func set(index: Int64, element: T): T {
        if (index < 0 || index >= this.mySize) {
            throw IndexOutOfBoundsException()
        }
        match (at(index)) {
            case Some(v) =>
                let oldValue = v.value
                v.value = element
                return oldValue
            case _ => throw IndexOutOfBoundsException()
        }
    }

    public func prepend(element: T): Unit {
        this.linkFirst(element)
    }

    public func append(element: T): Unit {
        this.linkLast(element)
    }

    public func appendAll(elements: Collection<T>): Unit {
        for (element in elements) {
            this.linkLast(element)
        }
    }

    public func insert(index: Int64, element: T): Unit {
        if (index < 0 || index > this.mySize) {
            throw IndexOutOfBoundsException()
        }
        if (index == 0) {
            this.linkFirst(element)
        } else if (index == this.mySize - 1) {
            this.linkLast(element)
        } else {
            this.linkBefore(element, at(index))
        }
    }

    public func remove(index: Int64): T {
        if (index < 0 || index >= this.mySize) {
            throw IndexOutOfBoundsException()
        }
        match (at(index)) {
            case Some(v) => this.unlink(v)
            case _ => throw IndexOutOfBoundsException()
        }
    }

    public func removeFirst(): T {
        match (first) {
            case Some(v) => this.unlinkFirst(v)
            case _ => throw IndexOutOfBoundsException()
        }
    }

    public func removeLast(): T {
        match (last) {
            case Some(v) => this.unlinkLast(v)
            case _ => throw IndexOutOfBoundsException()
        }
    }

    private func at(index: Int64): ?LinkedListNode<T> {
        if (index < (this.mySize >> 1)) {
            var firsts: ?LinkedListNode<T> = first
            for (_ in 0..index) {
                match (firsts) {
                    case Some(v) => firsts = v.next
                    case _ => ()
                }
            }
            firsts
        } else {
            var lasts = last
            var i = this.mySize - 1
            while (i > index) {
                match (lasts) {
                    case Some(v) => lasts = v.prev
                    case _ => ()
                }
                i--
            }
            lasts
        }
    }

    private func linkFirst(element: T): Unit {
        let first = this.first
        let newLinkedListNode = LinkedListNode(prev: None<LinkedListNode<T>>, value: element, next: first)
        this.first = newLinkedListNode
        match (first) {
            case Some(v) => v.prev = newLinkedListNode
            case _ => last = newLinkedListNode
        }
        this.mySize++
    }

    private func linkLast(element: T): Unit {
        let last = this.last
        let newLinkedListNode = LinkedListNode(prev: last, value: element, next: None<LinkedListNode<T>>)
        this.last = newLinkedListNode
        match (last) {
            case Some(v) => v.next = newLinkedListNode
            case _ => first = newLinkedListNode
        }
        this.mySize++
    }

    private func linkBefore(element: T, succ: ?LinkedListNode<T>): Unit {
        match (succ) {
            case Some(v) =>
                let pred = v.prev
                let newLinkedListNode = LinkedListNode(prev: pred, value: element, next: succ)
                v.prev = newLinkedListNode
                match (pred) {
                    case Some(v2) => v2.next = newLinkedListNode
                    case _ => first = newLinkedListNode
                }
                this.mySize++
            case _ => ()
        }
    }

    private func unlinkFirst(x: LinkedListNode<T>): T {
        let element = x.value
        let next = x.next
        x.next = None
        this.first = next
        match (next) {
            case Some(v) => v.prev = None
            case _ => last = None
        }
        this.mySize--
        element
    }

    private func unlinkLast(x: LinkedListNode<T>): T {
        let elements = x.value
        let prev = x.prev
        x.prev = None
        this.last = prev
        match (prev) {
            case Some(v) => v.next = None
            case _ => first = None
        }
        this.mySize--
        elements
    }

    private func unlink(x: LinkedListNode<T>): T {
        let element = x.value
        let next = x.next
        let prev = x.prev
        match (prev) {
            case Some(v) =>
                v.next = next
                x.prev = None
            case _ => first = next
        }
        match (next) {
            case Some(v) =>
                v.prev = prev
                x.next = None
            case _ => last = prev
        }
        this.mySize--
        element
    }
}

class LinkedListIterator<T> <: Iterator<T> {
    LinkedListIterator(var current: ?LinkedListNode<T>) {}

    public func next(): ?T {
        match (current) {
            case Some(v) =>
                let element = v.value
                current = v.next
                element
            case _ => None
        }
    }
}
