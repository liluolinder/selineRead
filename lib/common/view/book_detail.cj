@NonProduct
features {}
package ohos_app_cangjie_entry.view

internal import ohos.component.*
internal import ohos.base.*
internal import ohos.base.LengthProp
internal import ohos.state_manage.*
import ohos.state_macro_manage.*
import ohos_app_cangjie_entry.model.*

@Builder
public func BookDetailViewBuilder(){
    BookDetailView()
}

@Component
public class BookDetailView {
    var param: String = ""

    func build() {
        NavDestination {
            Column(8) {
                Text("详情")
                Text("param=" + this.param).fontSize(14).fontColor(cWeak())
            }
        }.onReady {
            ctx: NavDestinationContext => 
           
        }
    }
}
