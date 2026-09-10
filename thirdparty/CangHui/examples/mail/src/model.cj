/*
 * 邮件客户端状态：搜索词、选中邮件、已读集合与归档集合。
 *
 * 列表可见集 = 原序过滤（搜索命中且未归档）；选中即标已读；归档当前选中项时选中顺延到
 * 可见列表的相邻一封。集合更新沿用「复制 + 增删 + 整体重赋」惯例以触发重建。
 */
package chui_mail

import chui.State
import std.collection.{ArrayList, HashSet}

class MailModel {
    let mails: Array<Mail> = INBOX
    let query = State<String>("")
    let selectedId = State<Int64>(-1)
    let readIds: State<HashSet<Int64>>
    let archivedIds = State<HashSet<Int64>>(HashSet<Int64>())

    init() {
        // 预置部分已读，未读徽标与加粗行开屏即可见；默认选中第一封（随选中标记为已读）。
        let read = HashSet<Int64>()
        read.add(3)
        read.add(7)
        read.add(9)
        this.readIds = State<HashSet<Int64>>(read)
        select(mails[0].id)
    }

    // 搜索过滤后仍未归档的邮件，保持收件箱原序。
    func visible(): Array<Mail> {
        let out = ArrayList<Mail>()
        for (mail in mails) {
            if (!archivedIds.value.contains(mail.id) && matchesQuery(mail, query.value)) {
                out.add(mail)
            }
        }
        out.toArray()
    }

    func isUnread(id: Int64): Bool {
        !readIds.value.contains(id)
    }

    // 可见集内的未读数（徽标与计数行共用）。
    func unreadCount(): Int64 {
        var count: Int64 = 0
        for (mail in visible()) {
            if (isUnread(mail.id)) {
                count += 1
            }
        }
        count
    }

    func selectedMail(): ?Mail {
        for (mail in mails) {
            if (mail.id == selectedId.value && !archivedIds.value.contains(mail.id)) {
                return Some(mail)
            }
        }
        None
    }

    // 选中一封邮件并立即标为已读（桌面邮件客户端的通行为）。
    func select(id: Int64): Unit {
        selectedId.value = id
        if (isUnread(id)) {
            let next = copyOf(readIds.value)
            next.add(id)
            readIds.value = next
        }
    }

    // 把当前选中标回未读（保持选中，行恢复加粗与圆点）。
    func markSelectedUnread(): Unit {
        let next = copyOf(readIds.value)
        next.remove(selectedId.value)
        readIds.value = next
    }

    // 归档当前选中：从列表消失，选中顺延到可见列表中原位置的下一封（末尾则取前一封）。
    func archiveSelected(): Unit {
        let id = selectedId.value
        let before = visible()
        var index: Int64 = -1
        for (i in 0..before.size) {
            if (before[i].id == id) {
                index = i
            }
        }
        let next = copyOf(archivedIds.value)
        next.add(id)
        archivedIds.value = next
        if (index < 0) {
            return
        }
        let after = visible()
        if (after.isEmpty()) {
            selectedId.value = -1
            return
        }
        let landing = if (index < after.size) {
            index
        } else {
            after.size - 1
        }
        select(after[landing].id)
    }

    private func copyOf(source: HashSet<Int64>): HashSet<Int64> {
        let next = HashSet<Int64>()
        for (value in source) {
            next.add(value)
        }
        next
    }
}

// 搜索匹配：空词全命中；否则发件人/主题/预览任一包含即命中。
func matchesQuery(mail: Mail, query: String): Bool {
    if (query.isEmpty()) {
        return true
    }
    mail.sender.contains(query) || mail.subject.contains(query) || mail.preview.contains(query)
}
