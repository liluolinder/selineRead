import { min_width } from "../../../commons/commonItem"
import { __Download__, __System__ } from "../../../commons/shareDatas"
import { __CustomBackgroundData__ } from "../../../components/CustomBackground"
import {  ProgressButton } from "@kit.ArkUI"
import { DownloadInfo, DownloadStatus } from "../../../models/classes/DownloadInfo"

@Builder
export function DownloadPageBuilder(){
  DownloadPage()
}


@ComponentV2
export struct DownloadPage{

  @Local num:number=1

  aboutToAppear(): void {
     console.log(JSON.stringify(__Download__.downloadArray))
    console.log(JSON.stringify(__Download__.downloadArray.totalCount()))

  }

  build() {
    NavDestination(){
      if (__Download__.downloadArray.dataArray.length == 0)
      {
        Column(){
          Text('12412421')
        }
      }else {
        List({space:10}){
          LazyForEach(__Download__.downloadArray,(item:DownloadInfo)=>{
            ListItem(){
              Row({space:10}){
                Image(item.fileImage)
                  .aspectRatio(2/3)
                  .autoResize(true)
                  .height('100%')
                  .shadow({
                    radius: 25,
                    color: Color.Gray,
                    offsetX: 0,
                    offsetY: 10
                  })

                Column({space:5}){
                  Text(item.fileName)
                    .textOverflow({overflow:TextOverflow.Ellipsis})
                    .width('100%')
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)


                }
                .layoutWeight(1)

                Column(){
                  ProgressButton({
                    progress: item.progress,
                    progressButtonWidth:68,
                    content:item.status == DownloadStatus.Pause?'暂停':item.status == DownloadStatus.Complete?'已完成':'下载',
                    enable:item.status!=DownloadStatus.Complete,
                    clickCallback:()=>{
                      if (item.downLoadTask) {
                        switch (item.status){
                          case DownloadStatus.Idle:
                            item.downLoadTask.start()
                          case DownloadStatus.Downloading:
                            item.downLoadTask.pause()
                            break;
                          case DownloadStatus.Pause:
                            item.downLoadTask.resume()
                            break;
                          case DownloadStatus.Complete:
                            break;
                        }
                      }
                    }
                  })
                }
              }.size({ width: '100%', height: 100 })
              .justifyContent(FlexAlign.SpaceBetween)
              .padding(16)
            }.borderRadius(20)
            .backgroundColor($r('sys.color.comp_background_list_card'))
          },(item:DownloadInfo, index:number)=>JSON.stringify(item))
        }.height('100%')
        .width('100%')
        .padding({left:16, right:16})
      }
    }.size({ width: '100%', height: '100%' })
    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
    Color.Transparent : $r('sys.color.comp_background_gray'))
    .padding({ top: __System__.topRectHeight })
    .title($r('app.string.Title_DownloadManager'))

  }
}