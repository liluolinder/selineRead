package ohos_app_cangjie_entry.pages

internal import cjmp.net.connection.*
internal import ohos.arkui.component.*
internal import ohos.arkui.state_management.*
internal import ohos.base.*
import ohos.arkui.state_macro_manage.*
import ohos.hilog.Hilog


@Entry
@Component
public class Bookshelf {
    
    func build() {
         Column{
            Text("书架")
                .fontSize(24)
        }.size(width: 100.percent, height: 100.percent)
    }
}