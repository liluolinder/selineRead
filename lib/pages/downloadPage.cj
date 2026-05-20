package ohos_app_cangjie_entry.pages

import ohos.arkui.state_macro_manage.*
import ohos.hilog.Hilog


@Entry
@Component
public class DownloadPage {
    
    func build() {
        Column{
            Text("下载")
                .fontSize(24)
        }.size(width: 100.percent, height: 100.percent)
    }
}