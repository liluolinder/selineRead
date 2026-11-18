@NonProduct
features {}
package ohos_app_cangjie_entry

internal import ohos.component.*
internal import ohos.base.*
internal import ohos.state_manage.*
import ohos.state_macro_manage.*
import ohos_app_cangjie_entry.viewmodel.*
import ohos_app_cangjie_entry.model.*
import ohos_app_cangjie_entry.view.*

@Entry
@Component
class EntryView {
    @State
    var vm: SelineViewModel = SelineViewModel()

    protected override func aboutToAppear() {
        this.vm.start()
    }

    protected override func onBackPress(): Bool {
        return this.vm.handleBack()
    }

    @Builder
    func pageMap(name: String) {
        if (name == "BookDetail") {
           BookDetailViewBuilder()
        } else {
           BookDetailViewBuilder()
        }
    }

    func build() {
        Navigation(this.vm.pathStack) {
            Stack(Alignment.Bottom) {
                Row() {
                    if (this.vm.wide) {
                        SideBarView(vm: this.vm)
                    }
                    Stack(Alignment.Top) {
                        Tabs(this.vm.tabs, Int32(this.vm.tab)) {
                            TabContent {
                                HomeView(vm: this.vm)
                            }
                            TabContent {
                                BooklistView(vm: this.vm)
                            }
                            TabContent {
                                SavedView(vm: this.vm)
                            }
                            TabContent {
                                DownloadsView(vm: this.vm)
                            }
                            TabContent {
                                SettingsView(vm: this.vm)
                            }
                        }.barHeight(0).onChange {index: Int32 => this.vm.switchTab(Int64(index))}
                    }.layoutWeight(1).height(100.percent)
                }.width(100.percent).height(100.percent)

                if (!this.vm.wide) {
                    FloatingTabBarView(vm: this.vm)
                }
            }
                .width(100.percent)
                .height(100.percent)
                .backgroundColor(cBg())
                .onAreaChange {
                    _: Area, area: Area =>
                        WindowUtil.updateAvoidArea(area.width)
                        WindowUtil.updateScreenSize(area.width)
                        let nextWide = area.width >= 700.0
                        if (this.vm.wide != nextWide) {
                            this.vm.wide = nextWide
                        }
                }
        }
            //.mode(NavigationMode.Stack)
            .size(width: 100.percent, height: 100.percent)
            .navDestination(bind<String>(pageMap, this))
            //.hideToolBar(true)
            //.hideTitleBar(true)
    }
}
