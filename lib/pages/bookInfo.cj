package ohos_app_cangjie_entry.pages

import ohos.arkui.state_macro_manage.*
import ohos.hilog.Hilog


@Entry
@Component
public class BookInfoPage {
    
    func build() {
        Column{
            Text("书籍详细页")
                .fontSize(24)
        }.size(width: 100.percent, height: 100.percent)
    }
}