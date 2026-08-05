import { HdsNavDestination } from "@hms.hds.hdsBaseComponent";
import { ChapterArk } from "libohos_app_cangjie_entry.bookSource.so";
import { min_width } from "../../commons/commonItem";
import { __System__ } from "../../commons/shareDatas";
import { __CustomBackgroundData__ } from "../../components/CustomBackground";
import { hdsMaterial, IconStyleMode } from "@kit.UIDesignKit";
import { BasicDataSource } from "commonpackage";
import { ReaderParam } from "./BookInfo";

@Builder
export function ReaderBuilder(){
  Reader()
}

@ComponentV2
export struct Reader{

  @Local chapters: ChapterArk[] = []
  @Local startIndex: number = 0
  @Local currentIndex: number = 0
  @Local showChapterSheet: boolean = false
  /** 章节正文缓存（按下标存，未加载为 undefined），命中直接读，避免重复请求 */
  chapterCache: string[] = []
  /** 内容版本号：章节加载完成后自增，驱动 ReaderPage 刷新渲染 */
  @Local contentVersion: number = 0

  /** 获取一章正文并写入缓存（已缓存则跳过），完成后自增 contentVersion 触发渲染 */
  loadChapterContent(chIdx: number): void {
    if (chIdx < 0 || chIdx >= this.chapters.length) {
      return
    }
    if (this.chapterCache[chIdx] != undefined) {
      return
    }
    const ch = this.chapters[chIdx]
    ch.getContent((content) => {
      this.chapterCache[chIdx] = content
      this.contentVersion++
      console.log(`meow: Reader 获取章节"${ch.name}"成功，内容长度=${content.length}，已写入缓存`)
    }, (error) => {
      this.chapterCache[chIdx] = `加载失败：${error}`
      this.contentVersion++
      console.log(`meow: Reader 获取章节"${ch.name}"失败，error=${error}`)
    })
  }

  /** 预加载：以当前章为中心加载相邻章节（当前章 + 后 2 章） */
  preloadAround(chIdx: number): void {
    this.loadChapterContent(chIdx)
    this.loadChapterContent(chIdx + 1)
    this.loadChapterContent(chIdx + 2)
  }

  /** 章节列表半模态：展示全部章节，点击跳转到对应章节 */
  @Builder
  chapterSheet() {
    Column() {
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
          }
          .onClick(() => {
            this.showChapterSheet = false
            this.currentIndex = index
            this.preloadAround(index)
            console.log(`meow: Reader 半模态跳转到章节${index}`)
          })
        }, (item: ChapterArk, index: number) => `${item.url}-${index}`)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_gray'))
  }

  build() {
    HdsNavDestination(){
      Swiper() {
        ForEach(this.chapters, (chapter: ChapterArk, idx: number) => {
          ReaderPage({
            chapter: chapter,
            content: this.chapterCache[idx],
            version: this.contentVersion
          })
        }, (chapter: ChapterArk, idx: number) => chapter.url + idx)
      }
      .index(this.currentIndex)
      .loop(false)
      .indicator(false)
      .cachedCount(2)
      .width('100%')
      .height('100%')
      .onChange((idx: number) => {
        this.currentIndex = idx
        this.preloadAround(idx)
      })
    }
    .onReady((ctx)=>{
      let param = ctx.pathInfo.param as ReaderParam
      this.chapters = param.chapters
      this.startIndex = param.index
      this.currentIndex = param.index
      console.log(`meow: Reader onReady，章节数=${this.chapters.length}，起始索引=${this.startIndex}`)
      this.preloadAround(param.index)
    })
    .bindSheet($$this.showChapterSheet, this.chapterSheet(), {
      preferType: SheetType.CENTER,
      height: SheetSize.MEDIUM,
      title: { title: '目录' },
      showClose: true,
    })
    .size({ width: '100%', height: '100%' })
    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
      Color.Transparent : $r('sys.color.comp_background_gray'))
    .padding({ top: __System__.topRectHeight })
    .titleBar({
      enableComponentSafeArea: true,
      content:{
        title:{
          mainTitle:this.chapters[this.currentIndex]?.name ?? ''
        },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.list_bullet_square'),
                type: IconStyleMode.SMALL,
                action: () => {
                  this.showChapterSheet = true
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

@ComponentV2
export struct ReaderPage {
  @Param @Require chapter: ChapterArk
  /** 本章正文（undefined 表示未加载完成），父组件 contentVersion 自增时随重新渲染更新 */
  @Param content: string | undefined = undefined
  /** 内容版本号：父组件在 build 中读取它建立依赖，加载完成后自增触发本组件刷新 */
  @Param version: number = 0
  scroller: Scroller = new Scroller()

  /** 按换行符切分段落，去掉空行——渲染时每段独立 Text + textIndent 首行空 2 格 */
  splitParagraphs(content: string): string[] {
    this.content
    return content.split(/\r?\n/).filter((p) => p.trim() != '')
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        Text(this.chapter.name)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        if (this.content == undefined) {
          Column() {
            LoadingProgress()
              .size({ width: 50, height: 50 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          ForEach(this.splitParagraphs(this.content), (para: string, pIdx: number) => {
            Text(para)
              .fontSize(16)
              .lineHeight(28)
              .textIndent(32)
              .width('100%')
          }, (para: string, pIdx: number) => `${pIdx}`)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
