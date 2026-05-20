package ohos_app_cangjie_entry.components

internal import cjmp.net.connection.*
internal import ohos.base.LengthProp
internal import ohos.arkui.component.*
internal import ohos.arkui.state_management.*
internal import ohos.base.*
import ohos.arkui.state_macro_manage.*
import zlibraryAPI4CJ.common.*
import zlibraryAPI4CJ.dataModel.*
import zlibraryAPI4CJ.*
import ohos.hilog.Hilog

@Component
public class BookCover {
    @State
    var book: BookInfoBrief = BookInfoBrief()
    
    func build() {
        Column(space: 10) {
            Stack {
                Image(book.cover)
                    .objectFit(ImageFit.Auto)
                    .aspectRatio(2.0 / 3.0)
                    .autoResize(true)
            }
                .aspectRatio(2.0 / 3.0)
                .clip(true)
                .borderRadius(15)
                .shadow(radius: 25.0, color: Color.Gray, offsetX: 0.0, offsetY: 10.0)

            Column(space: 2) {
                Text(book.title)
                    .fontSize(16)
                    .maxLines(1)
                    .fontWeight(FontWeight.Bold)
                    .width(100.percent)

                Text(book.author)
                    .fontSize(12)
                    .maxLines(1)
                    .opacity(0.6)
                    .width(100.percent)
            }
        }
    }
}
