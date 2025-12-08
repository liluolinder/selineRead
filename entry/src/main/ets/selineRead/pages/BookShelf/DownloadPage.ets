import { min_width } from "../../commons/commonItem"
import { __Download__, __System__, __ZlibUser__ } from "../../commons/shareDatas"
import { __CustomBackgroundData__ } from "../../components/CustomBackground"
import { ProgressButton } from "@kit.ArkUI"
import { DownloadInfo, DownloadStatus } from "../../models/classes/DownloadInfo"
import { relationalStore } from "@kit.ArkData"
import { RelationStoreManager } from "../../models/classes/DataBase"
import { DownloadTask } from "@hadss/super_fast_file_trans"
import { http } from "@kit.NetworkKit"

@Builder
export function DownloadPageBuilder() {
  DownloadPage()
}


@ComponentV2
export struct DownloadPage {
  @Local num: number = 1

  @Builder
  editCustom(item: DownloadInfo, index: number) {
    Column() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(28)
          .fontColor([Color.White])

      }.padding(8)
      .backgroundColor($r('sys.color.warning'))
      .onClick(() => {
        __Download__.downloadArray.deleteData(index)
        if (item.downloadType == 'txt') {
          (item.downLoadTask as http.HttpRequest)?.destroy()
        } else {
          (item.downLoadTask as DownloadTask)?.cancel()
        }

        let predicates = new relationalStore.RdbPredicates('ZlibDownloadTable')
        predicates.equalTo('BookID', item.bookId).equalTo("BookDownLoadTime", item.downloadTime)
        RelationStoreManager.deleteValue(__ZlibUser__.dataBase, predicates)
      })
    }.padding({ left: 16, right: 16 })
  }

  build() {
    NavDestination() {
      if (__Download__.downloadArray.dataArray.length == 0) {
        Column() {
          Text($r('app.string.Tip_ThereAreNotEmptyAnyMore'))
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
        }.height('100%')
        .width('100%')
        .padding({ left: 16, right: 16 })
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          LazyForEach(__Download__.downloadArray, (item: DownloadInfo, index?: number) => {
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
                      item.status == DownloadStatus.Failed ? '失败' :
                        item.status == DownloadStatus.Starting ? '启动中' :
                          item.status == DownloadStatus.Downloading ? '下载中' : item.status == DownloadStatus.Cancel ?'已取消':'下载',
                    enable: item.status != DownloadStatus.Complete && item.status != DownloadStatus.Failed ,
                    clickCallback: () => {
                      if (item.downLoadTask && item.downloadType == 'other') {
                        switch (item.status) {
                          case DownloadStatus.Idle:
                          case DownloadStatus.Cancel:
                            //处于初始化就启动
                            (item.downLoadTask as DownloadTask).start();
                            break;
                          case DownloadStatus.Starting:
                            //处于正在启动，不处理
                            break;
                          case DownloadStatus.Downloading:
                            (item.downLoadTask as DownloadTask).cancel();
                            break;
                          case DownloadStatus.Complete:
                            //处于下载完成，不处理
                            break;
                          case DownloadStatus.Failed:
                            //处于下载失败，后续实现
                            break;
                        }
                      } else if (item.downloadType == 'txt') {
                        if (item.status == DownloadStatus.Downloading) {
                          (item.downLoadTask as http.HttpRequest).destroy()
                          item.status = DownloadStatus.Cancel
                        }
                      }
                    }
                  })
                }
              }
              .size({ width: '100%', height: 100 })
              .justifyContent(FlexAlign.SpaceBetween)
              .padding(16)
              .backgroundColor($r('sys.color.comp_background_list_card'))
              .borderRadius(20)
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.editCustom(item, index)
                },
              }
            })
          }, (item: DownloadInfo, index: number) => JSON.stringify(item) + JSON.stringify(index))
        }.height('100%')
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
    }.size({ width: '100%', height: '100%' })
    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
    Color.Transparent : $r('sys.color.comp_background_gray'))
    .padding({ top: __System__.topRectHeight })
    .title($r('app.string.Title_DownloadManager'))

  }
}