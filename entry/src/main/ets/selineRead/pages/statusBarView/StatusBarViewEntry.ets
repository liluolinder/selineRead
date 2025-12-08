import { DownloadPage } from "../BookShelf/DownloadPage"
import { BusinessError, commonEventManager, emitter } from "@kit.BasicServicesKit";
import { BasicDataSource } from "commonpackage";
import { DownloadInfo, DownloadStatus } from "../../models/classes/DownloadInfo";
import { ProgressButton } from "@kit.ArkUI";


@ObservedV2
class StatusBarInfo{
   downloadArray:BasicDataSource<DownloadInfo> = new BasicDataSource<DownloadInfo>()
}

export let __StatusBar__:StatusBarInfo = new StatusBarInfo()

@Entry
@ComponentV2
struct StatusBarViewEntry{

  build() {
    Column(){
      if (__StatusBar__.downloadArray.dataArray.length == 0) {
        Column() {
          Text($r('app.string.Tip_ThereAreNotEmptyAnyMore'))
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
        }.height('100%')
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          LazyForEach(__StatusBar__.downloadArray, (item: DownloadInfo) => {
            ListItem() {
              Row({ space: 10 }) {
                Image(item.fileImage)
                  .aspectRatio(2 / 3)
                  .autoResize(true)
                  .height('100%')
                  .shadow({
                    radius: 25,
                    color: Color.Gray,
                    offsetX: 0,
                    offsetY: 10
                  })

                Column({ space: 5 }) {
                  Text(item.fileName)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                }
                .layoutWeight(1)

                Column() {
                  ProgressButton({
                    progress: item.progress,
                    progressButtonWidth: 68,
                    content: item.status == DownloadStatus.Complete ? '已完成' :
                      item.status == DownloadStatus.Failed ? '失败' : item.status == DownloadStatus.Starting ? '启动中' :'下载',
                    enable: item.status != DownloadStatus.Complete && item.status != DownloadStatus.Failed,
                    clickCallback: () => {
                    }
                  })
                }
              }.size({ width: '100%', height: 100 })
              .justifyContent(FlexAlign.SpaceBetween)
              .padding(16)
            }.borderRadius(20)
            .backgroundColor($r('sys.color.comp_background_list_card'))
          }, (item: DownloadInfo, index: number) => JSON.stringify(item))
        }.height('100%')
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
    }
  }
}