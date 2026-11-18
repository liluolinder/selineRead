@NonProduct
features {}

package ohos_app_cangjie_entry.view

internal import ohos.component.*
internal import ohos.base.*
internal import ohos.base.LengthProp
internal import ohos.state_manage.*
import ohos.state_macro_manage.*
import ohos_app_cangjie_entry.viewmodel.*

@Component
public class SideBarView {
    @Link var vm: SelineViewModel

    func build() {
        Column(6) {
            Text("SelineRead").fontSize(20).fontWeight(FontWeight.Bold).fontColor(cText()).width(100.percent).padding(bottom: 12)
            Text("首页").fontSize(15).fontColor(if (this.vm.tab == 0) { cAccent() } else { cText() }).width(100.percent).padding(12).borderRadius(10)
                .backgroundColor(if (this.vm.tab == 0) { cAccentSoft() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(0) }
            Text("书单").fontSize(15).fontColor(if (this.vm.tab == 1) { cAccent() } else { cText() }).width(100.percent).padding(12).borderRadius(10)
                .backgroundColor(if (this.vm.tab == 1) { cAccentSoft() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(1) }
            Text("收藏").fontSize(15).fontColor(if (this.vm.tab == 2) { cAccent() } else { cText() }).width(100.percent).padding(12).borderRadius(10)
                .backgroundColor(if (this.vm.tab == 2) { cAccentSoft() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(2) }
            Text("下载").fontSize(15).fontColor(if (this.vm.tab == 3) { cAccent() } else { cText() }).width(100.percent).padding(12).borderRadius(10)
                .backgroundColor(if (this.vm.tab == 3) { cAccentSoft() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(3) }
            Text("设置").fontSize(15).fontColor(if (this.vm.tab == 4) { cAccent() } else { cText() }).width(100.percent).padding(12).borderRadius(10)
                .backgroundColor(if (this.vm.tab == 4) { cAccentSoft() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(4) }
        }
        .width(220).height(100.percent).padding(top: this.vm.window.topRectHeight + 12.0, left: 12, right: 12).backgroundColor(cCard())
    }
}

@Component
public class FloatingTabBarView {
    @Link var vm: SelineViewModel

    func build() {
        Row() {
            Text("首页").fontSize(12).fontColor(if (this.vm.tab == 0) { Color(0xFFFFFFFF) } else { cText() }).textAlign(TextAlign.Center).height(42).layoutWeight(1).borderRadius(21)
                .backgroundColor(if (this.vm.tab == 0) { cAccent() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(0) }
            Text("书单").fontSize(12).fontColor(if (this.vm.tab == 1) { Color(0xFFFFFFFF) } else { cText() }).textAlign(TextAlign.Center).height(42).layoutWeight(1).borderRadius(21)
                .backgroundColor(if (this.vm.tab == 1) { cAccent() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(1) }
            Text("收藏").fontSize(12).fontColor(if (this.vm.tab == 2) { Color(0xFFFFFFFF) } else { cText() }).textAlign(TextAlign.Center).height(42).layoutWeight(1).borderRadius(21)
                .backgroundColor(if (this.vm.tab == 2) { cAccent() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(2) }
            Text("下载").fontSize(12).fontColor(if (this.vm.tab == 3) { Color(0xFFFFFFFF) } else { cText() }).textAlign(TextAlign.Center).height(42).layoutWeight(1).borderRadius(21)
                .backgroundColor(if (this.vm.tab == 3) { cAccent() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(3) }
            Text("设置").fontSize(12).fontColor(if (this.vm.tab == 4) { Color(0xFFFFFFFF) } else { cText() }).textAlign(TextAlign.Center).height(42).layoutWeight(1).borderRadius(21)
                .backgroundColor(if (this.vm.tab == 4) { cAccent() } else { Color.TRANSPARENT }).onClick { _ => this.vm.switchTab(4) }
        }
        .width(94.percent).height(54).padding(left: 5, right: 5).borderRadius(27).backgroundColor(cCard()).margin(bottom: this.vm.window.bottomRectHeight)
    }
}


