package ohos_app_cangjie_entry

internal import cjmp.net.connection.*
internal import ohos.arkui.component.*
internal import ohos.arkui.state_management.*
internal import ohos.base.*
import ohos.resource.*
import ohos.arkui.state_macro_manage.*
import zlibraryAPI4CJ.common.*
import zlibraryAPI4CJ.dataModel.*
import zlibraryAPI4CJ.*
import ohos.hilog.Hilog

import ohos_app_cangjie_entry.pages.*



@Entry
@Component
class EntryView {
    
    var tabs:Array<String> = ['主页','书架','下载','我的']

    var tabController: TabsController = TabsController()
    
    func build() {

        Stack(alignContent:Alignment.Bottom){
            
            Tabs(barPosition:BarPosition.End, controller:tabController){
                 TabContent() {
                   Home()
                }.tabBar("Home")

                 TabContent() {
                   Bookshelf()
                }.tabBar("Bookshelf")

                 TabContent() {
                   DownloadPage()
                }.tabBar("DownloadPage")
            }.size(width: 100.percent, height: 100.percent)
            .barWidth(0)
            .barHeight(0)

            //TODO:待backdropBlur属性可用时切换过来
            Stack{
                Row{}.size(width: 100.percent, height: 100.percent).backgroundColor(Color.White).blur(200.0)
                Row(space:10){
                    ForEach(tabs, itemGeneratorFunc: { item: String, index: Int64 => 
                        Column{
                            Text(item)
                            .fontSize(14)
                        }.size(width:70, height:100.percent)
                        .justifyContent(FlexAlign.End)
                        .onClick({
                            _=>
                            tabController.changeIndex(Int32(index))
                        })
                    }, keyGeneratorFunc: {item: String, idx: Int64 => return item})
                }.size(width: 100.percent, height: 100.percent)
                .backgroundColor(Color.Transparent)
                .justifyContent(FlexAlign.SpaceEvenly)
                .padding(left:16, right:16, top:4, bottom:4)
            }.size(width: 342, height: 54)
            .shadow(radius: 25.0, color: Color.Gray, offsetX: 0.0, offsetY: 10.0)
            .borderRadius(25)
            .clip(true)
            .margin(bottom:8)

        }

        
    }
}