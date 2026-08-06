import { HdsNavDestination } from "@hms.hds.hdsBaseComponent"
import { BookArk, ChapterArk } from "libohos_app_cangjie_entry.bookSource.so"
import { min_width } from "../../commons/commonItem"
import { __System__ } from "../../commons/shareDatas"
import { __CustomBackgroundData__ } from "../../components/CustomBackground"
import { hdsMaterial, IconStyleMode } from "@kit.UIDesignKit"
import { UIUtils } from "@kit.ArkUI"
import { XAnimation, XContext } from "commonpackage"

@Builder
export function  BSBookInfoBuilder(){
  BookInfo()
}

export interface ReaderParam{
  chapters:ChapterArk[]
  index:number
}

@ComponentV2
export struct BookInfo{

  @Local bookInfo?:BookArk = undefined
  @Local isIntroExpanded: boolean = false
  @Local chapters:ChapterArk[] =[]
  @Local showChapter:boolean = false
  /** 目录是否加载中：getToc 异步回调完成前置为 true，成功后置 false */
  @Local tocLoading: boolean = false
  /** 目录骨架屏呼吸闪烁动画值 */
  @Local private tocPulse: number = 0.5
  /** 骨架屏占位行数 */
  @Local private skeletonRows: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

  pathStack:NavPathStack = new NavPathStack()

  aboutToAppear(): void {
    XAnimation.skeletonAnimation(()=>{this.tocPulse = 1})
  }

  cardBg(): ResourceColor {
    return __CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
      $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card')
  }

  /** 目录加载中骨架图：布局与真实章节行一致（序号+章节名），带呼吸闪烁动画 */
  @Builder
  chapterSkeleton() {
    Column() {
      ForEach(this.skeletonRows, (index: number) => {
        Row({ space: 12 }) {
          Row()
            .width(32)
            .height(16)
            .borderRadius(6)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
          Row()
            .width(index % 3 == 0 ? '75%' : (index % 3 == 1 ? '55%' : '65%'))
            .height(16)
            .borderRadius(6)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      }, (index: number) => index.toString())
    }
    .width('100%')
    .height(400)
    .opacity(this.tocPulse)
  }

  @Builder
  chapterSheet() {
    Column() {
      if (this.tocLoading) {
        this.chapterSkeleton()
      } else if (this.chapters.length == 0) {
        Column({ space: 8 }) {
          Text('暂无目录')
            .fontSize(16)
            .opacity(0.4)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 4 }) {
          ForEach(this.chapters, (item: ChapterArk, index: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Text(`${index + 1}`)
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
                  .width(32)
                Text(item.name)
                  .fontSize(15)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            }.onClick(()=>{
              let param : ReaderParam = {
                chapters:this.chapters,
                index:index
              }
              this.showChapter = false
              this.pathStack.pushPathByName("Reader",param)
            })
          })
        }
        .width('100%')
        .height('100%')
        .padding({left:16, right:16})
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .contentEndOffset(Math.max(16, __System__.bottomRectHeight))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_gray'))
  }

  build() {
    HdsNavDestination(){
      List({ space: 10 }) {
        ListItem() {
          Row({ space: 20 }) {
            Image(this.bookInfo?.coverUrl ?? $r('app.media.default_cover'))
              .objectFit(ImageFit.Cover)
              .borderRadius(15)
              .size({ height: 160, width: 116 })

            Column({ space: 5 }) {
              Text(this.bookInfo?.name ?? '')
                .fontWeight(FontWeight.Bold)
                .fontSize(24)
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.bookInfo?.author ?? '')
                .maxLines(3)
                .fontSize(18)
                .opacity(0.6)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .padding(16)
          .width('100%')
        }
        .backgroundColor(this.cardBg())
        .borderRadius(20)

        ListItem() {
          Column({ space: 8 }) {
            Text('简介')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text(this.bookInfo?.intro == '' || this.bookInfo?.intro == undefined ? '暂无简介' : this.bookInfo?.intro)
              .fontSize(15)
              .lineHeight(22)
              .maxLines(this.isIntroExpanded ? undefined : 5)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.bookInfo?.intro != '' && this.bookInfo?.intro != undefined) {
              Text(this.isIntroExpanded ? '收起' : '展开')
                .fontSize(13)
                .fontColor($r('sys.color.font_secondary'))
                .padding({ top: 4 })
                .onClick(() => {
                 XAnimation.runWithAnimation(()=>{this.isIntroExpanded = !this.isIntroExpanded})
                })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
        }
        .backgroundColor(this.cardBg())
        .borderRadius(20)

        ListItem() {
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              Text('分类')
                .fontSize(14)
                .opacity(0.6)
              Text(this.bookInfo?.kind == '' || this.bookInfo?.kind == undefined ? '未知' : this.bookInfo?.kind)
                .fontSize(14)
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')

            Row({ space: 12 }) {
              Text('字数')
                .fontSize(14)
                .opacity(0.6)
              Text(this.bookInfo?.wordCount == '' || this.bookInfo?.wordCount == undefined ? '未知' : this.bookInfo?.wordCount)
                .fontSize(14)
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')

            Row({ space: 12 }) {
              Text('最新章节')
                .fontSize(14)
                .opacity(0.6)
              Text(this.bookInfo?.latestChapter == '' || this.bookInfo?.latestChapter == undefined ? '未知' : this.bookInfo?.latestChapter)
                .fontSize(14)
                .layoutWeight(1)
                .textAlign(TextAlign.End)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')

            Row({ space: 12 }) {
              Text('书源')
                .fontSize(14)
                .opacity(0.6)
              Text(this.bookInfo?.sourceUrl == '' || this.bookInfo?.sourceUrl == undefined ? '未知' : this.bookInfo?.sourceUrl)
                .fontSize(14)
                .layoutWeight(1)
                .textAlign(TextAlign.End)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
        }
        .backgroundColor(this.cardBg())
        .borderRadius(20)
      }
      .padding({left:16, right:16})
      .width('100%')
      .height('100%')
      .contentEndOffset(Math.max(16, __System__.bottomRectHeight))
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .bindSheet($$this.showChapter, this.chapterSheet(), {
      preferType: SheetType.CENTER,
      height: SheetSize.FIT_CONTENT,
      title: { title: '目录' },
    })
    .onReady((ctx)=>{
      this.pathStack = ctx.pathStack
      this.bookInfo = UIUtils.makeObserved(ctx.pathInfo.param as BookArk);
      this.bookInfo.getBookInfo((newInfo)=>{
        if (this.bookInfo == undefined) {
          return
        }
        if (this.bookInfo.bookUrl == '') {
          this.bookInfo.bookUrl = newInfo.bookUrl
        }
        if (this.bookInfo.name == '') {
          this.bookInfo.name = newInfo.name
        }
        if (this.bookInfo.author == '') {
          this.bookInfo.author = newInfo.author
        }
        if (this.bookInfo.coverUrl == '') {
          this.bookInfo.coverUrl = newInfo.coverUrl
        }
        if (this.bookInfo.intro == '') {
          this.bookInfo.intro = newInfo.intro
        }
        if (this.bookInfo.kind == '') {
          this.bookInfo.kind = newInfo.kind
        }
        if (this.bookInfo.wordCount == '') {
          this.bookInfo.wordCount = newInfo.wordCount
        }
        if (this.bookInfo.latestChapter == '') {
          this.bookInfo.latestChapter = newInfo.latestChapter
        }
        if (this.bookInfo.sourceUrl == '') {
          this.bookInfo.sourceUrl = newInfo.sourceUrl
        }
      },(error)=>{})
      this.tocLoading = true
      this.bookInfo.getToc((toc)=>{
        this.chapters.push(...toc)
        this.tocLoading = false
      },(error)=>{
        this.tocLoading = false
      })
    })
    .size({ width: '100%', height: '100%' })
    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
      Color.Transparent : $r('sys.color.comp_background_gray'))
    .padding({ top: __System__.topRectHeight })
    .titleBar({
      enableComponentSafeArea: true,
      content:{
        title:{
          mainTitle:this.bookInfo?.name ?? ''
        },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.character_upper_plus'),
                type: IconStyleMode.SMALL,
                action: () => {
                  this.showChapter = true
                }
              }
            },
          ]
        }
      },
      style: {
        systemMaterialEffect: {
          materialType:hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        },
        scrollEffectOpts: {
          enableScrollEffect: false,
        },
      }
    })
  }
}
