package chui.text

import chui.core.{ComponentProbe, ProbeProperty, State, VStack}

@Test
func textFieldEmitsPlaceholderAndTextInputSemantics(): Unit {
    let name = State<String>("")
    let report = ComponentProbe("test.textfield-placeholder-semantics", width: 360.0, height: 120.0).run("") {
        VStack {
            TextField(name, key: "semantic-name", placeholder: "请输入姓名")
                .accessibilityLabel("姓名")
        }
    }

    @Expect(report.contains("\"id\":\"control-semantic:semantic-name\""))
    @Expect(report.contains("\"role\":\"textfield\""))
    @Expect(report.contains("\"label\":\"姓名\""))
    @Expect(report.contains("\"placeholder\":\"请输入姓名\""))
    @Expect(report.contains("\"action\":\"TextField.edit()\""))
    @Expect(report.contains("\"shortcut\":\"TextInput\""))

    let ascii = ComponentProbe("test.textfield-placeholder-ascii", width: 360.0, height: 120.0)
        .run("@cui-ascii 60 20") {
            TextField(name, key: "ascii-name", placeholder: "name here").accessibilityLabel("Name")
        }
    @Expect(ascii.contains("TextField.edit()"))
    @Expect(ascii.contains("Name"))
}

@Test
func textFieldSemanticsCarryCurrentValueAndStablePlaceholder(): Unit {
    let name = State<String>("")
    let emptyReport = ComponentProbe("test.textfield-empty-semantics", width: 360.0, height: 120.0).run("") {
        VStack {
            TextField(name, key: "semantic-empty", placeholder: "hint").accessibilityLabel("Name")
        }
    }
    @Expect(emptyReport.contains("\"placeholder\":\"hint\""))
    @Expect(emptyReport.contains("\"label\":\"Name\""))

    name.value = "Ada"
    let filledReport = ComponentProbe("test.textfield-filled-semantics", width: 360.0, height: 120.0).run("") {
        VStack {
            TextField(name, key: "semantic-filled", placeholder: "hint").accessibilityLabel("Name")
        }
    }
    @Expect(filledReport.contains("\"value\":\"Ada\""))
    @Expect(filledReport.contains("\"placeholder\":\"hint\""))
}

@Test
func readOnlyTextFieldReportsRoleAndValueWithoutAction(): Unit {
    let name = State<String>("fixed")
    let report = ComponentProbe("test.textfield-readonly-semantics", width: 360.0, height: 120.0).run("") {
        VStack {
            TextField(name, key: "semantic-ro", editable: false, placeholder: "n/a")
        }
    }
    @Expect(report.contains("\"id\":\"control-semantic:semantic-ro\""))
    @Expect(report.contains("\"role\":\"textfield\""))
    @Expect(report.contains("\"value\":\"fixed\""))
    @Expect(!report.contains("\"action\":\"TextField.edit()\""))
}

@Test
func explicitTextFieldProbeKeepsSameOwnerPrecedence(): Unit {
    let name = State<String>("")
    let report = ComponentProbe("test.explicit-textfield-probe", width: 360.0, height: 120.0).run("") {
        VStack {
            TextField(name, key: "explicit-name", placeholder: "hint")
                .probe("explicit-name", "TextField", [
                    ProbeProperty("role", "textfield"),
                    ProbeProperty("label", "Explicit name"),
                    ProbeProperty("action", "name.edit()")
                ])
        }
    }
    @Expect(report.contains("\"id\":\"explicit-name\""))
    @Expect(report.contains("\"action\":\"name.edit()\""))
    @Expect(!report.contains("control-semantic:explicit-name"))
}

@Test
func secureTextFieldRedactsValueAndAdvertisesPasswordRole(): Unit {
    let password = State<String>("päss秘密")
    let report = ComponentProbe("test.secure-textfield-semantics", width: 360.0, height: 120.0).run("") {
        VStack {
            TextField(password, key: "secure-password", placeholder: "Password")
                .accessibilityLabel("SSH password")
                .secureEntry()
        }
    }

    @Expect(report.contains("\"role\":\"password\""))
    @Expect(report.contains("\"label\":\"SSH password\""))
    @Expect(!report.contains("päss秘密"))
}
