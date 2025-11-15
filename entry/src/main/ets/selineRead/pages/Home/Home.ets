import { curves, UIUtils } from "@kit.ArkUI"
import { BasicDataSource, XAnimation, XContext } from "commonpackage"
import { min_width } from "../../commons/commonItem"
import { __System__ } from "../../commons/shareDatas"
import { I_BookInfo } from "../../models/interfaces/I_BookInfo"
import { http } from "@kit.NetworkKit"
import { zlibClient } from "../../../zlibrary/zlibClient"
import { it } from "@ohos/hypium"
import { loadingDialog, loadingNewDialog } from "../../components/LoadingNewDialog"
import { resourceManager } from "@kit.LocalizationKit"


@ObservedV2
export class HomeData {
  @Trace inSearchMode: boolean = false
}

export const __Home__ = new HomeData()

@ComponentV2
export struct Home {
  @Local waterFlowColumnNumber: number = -1
  @Local waterFlowEmptyItem: number[] = []
  @Local recommendBookIndex: number = 1
  @Local columnNumber: number = 0
  @Local canGetMore: boolean = false
  @Local recommendBookArray: BasicDataSource<I_BookInfo> =
    new BasicDataSource<I_BookInfo>()
  @Local errorText:string = ''

  async aboutToAppear() {
    let req = http.createHttp()
    zlibClient.getRecommendBook(req, this.recommendBookIndex).then((res) => {
      this.canGetMore = true
      if (res[0] == 1) {
        (JSON.parse(res[1]) as I_BookInfo[]).forEach((item) => {
          this.recommendBookArray.pushData(UIUtils.makeObserved(item))
        })
        this.recommendBookIndex++
        this.errorText = ''
      }else {
        this.errorText = res[1]
      }
      console.log(res.toString())
    })

  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row({ space: 10 }) {
        Search()
          .width(__Home__.inSearchMode ? '100%' : "45%")
          .focusable(__Home__.inSearchMode)
          .onSubmit((value: string) => {
            XAnimation.runWithAnimation(() => {
              __Home__.inSearchMode = false
            })
            if (value != '') {

              // __Client__.searchSong(value, true)
            }
          })
          .onChange((value: string) => {
            if (value == '' || value == undefined) {
              XAnimation.runWithAnimation(() => {

              })
            }
          })
          .onTouch(() => {
            XAnimation.runWithAnimation(() => {
              __Home__.inSearchMode = true
            })
          })
      }
      .zIndex(1)
      .justifyContent(FlexAlign.End)
      .width('100%')
      .padding({ top: Math.max(__System__.topRectHeight, 16), left: 16, right: 16 })
      .transition(XAnimation.getAnimation('up'))
      .zIndex(114514)

      if (this.recommendBookArray.totalCount() == 0)
      {
        Column({space:10}){
          LoadingProgress()
            .height(75)
          Text(this.errorText == ''?$r('app.string.Tip_GettingBookNow'):XContext.getStringFromResource($r('app.string.Tip_GettingError'))+'\n'+this.errorText)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
        } .height('100%')
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }else {
        WaterFlow() {
          ForEach(this.waterFlowEmptyItem, () => {
            FlowItem().height(__System__.topRectHeight + 60)
          })
          LazyForEach(this.recommendBookArray, (item: I_BookInfo) => {
            FlowItem() {
              Column({ space: 10 }) {
                Stack() {
                  Image($r('app.media.default_cover'))
                    .aspectRatio(0.71)
                    .visibility((item.isReady ?? false) ? Visibility.None : Visibility.Visible)
                    .animation({ duration: 100 })
                    .draggable(false)
                    .objectFit(ImageFit.Cover)
                  Image(item.cover ?? $r('app.media.default_cover'))
                    .visibility((item.isReady ?? false) ? Visibility.Visible : Visibility.Hidden)
                    .animation({ duration: 150, curve: Curve.Ease })
                    .draggable(false)
                    .onComplete(() => {
                      item.isReady = true
                    })
                }
                .clip(true)
                .borderRadius(15)
                .shadow({
                  radius: 25,
                  color: Color.Gray,
                  offsetX: 0,
                  offsetY: 10
                })

                Column({ space: 2 }) {
                  Text(item.title)
                    .fontSize(16)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.MARQUEE }).fontWeight(FontWeight.Medium)
                  Text(item.author)
                    .fontSize(12)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.6)
                }.alignItems(HorizontalAlign.Start)
              }
            }
            .width('100%')
            .borderRadius(20)
            .padding(16)
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .transition(TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
              .animation({ curve: curves.springMotion(0.5, 0.7) }))
          })
        }
        .onAreaChange((_, newValue) => {
          XAnimation.runWithAnimation(() => {
            this.waterFlowColumnNumber = Math.max(Math.ceil(new Number(newValue.width).valueOf() / 240), 2)
            let itemList: number[] = []
            for (let index = 0; index < this.waterFlowColumnNumber; index++) {
              itemList.push(index)
            }
            this.waterFlowEmptyItem = itemList
          }, this.waterFlowColumnNumber > 0)
        })
        .onScrollIndex(async (first: number, last: number) => {
          let totalCount: number = this.recommendBookArray.totalCount();
          if (last + this.waterFlowColumnNumber * 2 >= totalCount) {
            let req = http.createHttp()
            if (this.canGetMore) {
              this.canGetMore = false
              await zlibClient.getRecommendBook(req, this.recommendBookIndex).then((res) => {
                if (res[0] == 1) {
                  this.recommendBookIndex ++
                  (JSON.parse(res[1]) as I_BookInfo[]).forEach((item) => {
                    this.recommendBookArray.pushData(item)
                  })
                  this.errorText = ''
                }else {
                  this.errorText = res[1]
                }
                this.canGetMore = true
              })
            }
          }
        })
        .alignSelf(ItemAlign.Center)
        .align(Alignment.Center)
        .edgeEffect(EdgeEffect.Spring)
        .columnsTemplate(`repeat(${this.waterFlowColumnNumber},1fr)`)
        .columnsGap(10)
        .rowsGap(10)
        .height('100%')
        .width('100%')
        .padding({ left: 16, right: 16 })
      }

      if (this.errorText != '' && this.recommendBookArray.dataArray.length != 0) {
        Stack() {
          Column({ space: 10 }) {
            LoadingProgress().size({ width: 100, height: 100 })
            Text(XContext.getStringFromResource($r('app.string.Tip_GettingError'))+'\n'+this.errorText).fontSize(20).fontWeight(FontWeight.Medium).textAlign(TextAlign.Center)
          }.borderRadius(20).padding(20).backgroundColor($r('app.color.start_window_background_blur')).backdropBlur(100)
        }
        .size({ width: '100%', height: '100%' })
        .padding(16)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.Ease, duration: 300 }))
        .zIndex(114514)
      }

      if (__Home__.inSearchMode) {
        Column()
          .size({ width: '100%', height: '100%' })
          .onClick(() => {
            XAnimation.runWithAnimation(() => {
              __Home__.inSearchMode = false
            })
          })
      }

    }.size({ width: '100%', height: '100%' })

  }
}



