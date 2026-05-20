package ohos_app_cangjie_entry.pages


import ohos.arkui.state_macro_manage.*
import ohos.hilog.Hilog
import zlibraryAPI4CJ.common.*
import zlibraryAPI4CJ.dataModel.*
import zlibraryAPI4CJ.*
import ohos_app_cangjie_entry.components.BookCover
import ohos.arkui.ui_context.*

@Entry
@Component
public class Home {
    
    @State
    var books:Array<BookInfoBrief> = Array<BookInfoBrief>()
    
    protected func aboutToAppear():Unit {
         spawn{
            
            Hilog.info(1145,'meow','meow:124141241')
            let flag = canAccessZlib(autoRedirect: true)
            Hilog.info(1145,'meow',"${flag}")
            if(canAccessZlib(autoRedirect: true)){
                let zlibClient = ZlibClient()
                launch{
                    books = zlibClient.getRecommendBook().books.getOrThrow()
                }
            }
         }
    }

    func build() {
        Stack(alignContent:Alignment.Top) {
                //TODO:待backdropBlur属性可用时切换过来
                 Stack{
                    Row{}.size(width: 100.percent, height: 100.percent).backgroundColor(Color.White).blur(200.0)
                    Search( value: '')
                    .size(width: 100.percent, height: 100.percent)
                 }.size(width:100.percent, height:42)
                  .shadow(radius: 25.0, color: Color.Gray, offsetX: 0.0, offsetY: 10.0)
                  .borderRadius(25)
                  .clip(true)
                  .zIndex(2)

                List (space:10){
                    ForEach(books, itemGeneratorFunc: {
                        item: BookInfoBrief, _: Int64 => 
                        ListItem() {
                            BookCover(book:item)
                        }.margin(left:5, right:5)
                        .borderRadius(20)
                        .padding(16)
                        .backgroundColor(Color.White)
                        .onClick({_=>
                            getUIContext().getRouter().pushUrl(
                                url:"BookInfoPage",
                                params: ''
                            )   
                        })
                    }, keyGeneratorFunc: {item: BookInfoBrief, idx: Int64 => return item.title + item.hash})
                }
                    .size(width: 100.percent, height: 100.percent)
                    .lanes(2)
            }.size(width: 100.percent, height: 100.percent)
            .backgroundColor(Color.Gray)
            .padding(left:16, right:16)
    }

}