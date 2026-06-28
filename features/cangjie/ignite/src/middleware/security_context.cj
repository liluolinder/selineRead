package ignite.middleware

import ignite.Ctx

func markSecurityContext(
    ctx: Ctx,
    eventName: String,
    code: String,
    source: String,
    detail: String
): Unit {
    let existing = ctx.getLocal("__ignite_sec_event") ?? ""
    if (existing.size == 0) {
        ctx.setLocal("__ignite_sec_event", eventName)
    } else if (!securityCsvContains(existing, eventName)) {
        ctx.setLocal("__ignite_sec_event", existing + "," + eventName)
    }
    ctx.setLocal("__ignite_sec_code", code)
    ctx.setLocal("__ignite_sec_source", source)
    ctx.setLocal("__ignite_sec_detail", detail)
}

func securityCsvContains(csv: String, target: String): Bool {
    for (item in csv.split(",")) {
        if (item.trimAscii() == target) {
            return true
        }
    }
    false
}
