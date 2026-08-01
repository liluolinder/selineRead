import { __CustomBackgroundData__ } from '../../../components/CustomBackground'
import { __System__ } from '../../../commons/shareDatas'
import { min_width } from '../../../commons/commonItem'

/**
 * BookInfo 页骨架屏：在书籍详情异步加载完成前展示，
 * 布局与真实页面保持一致（封面卡片/简介卡片/信息行卡片/下载按钮），
 * 并带呼吸式闪烁动画。
 */
@ComponentV2
export struct BookInfoSkeleton {
  @Local private pulse: number = 0.5
  @Local private rows: number[] = [0, 1, 2, 3, 4, 5]

  aboutToAppear(): void {
    animateTo({
      duration: 700,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.pulse = 1
    })
  }

  @Builder
  private Block(width: Length, height: Length, radius: number) {
    Row()
      .width(width)
      .height(height)
      .borderRadius(radius)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  private getCardColor(): Resource {
    return __CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
      $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card')
  }

  private getCardBlur(): number | undefined {
    return __CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ? 100 : undefined
  }

  private getPageBg(): Resource {
    return __CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
      $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_gray')
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        // 封面 + 标题/作者卡片
        Row({ space: 20 }) {
          this.Block(116, 160, 12)
          Column({ space: 14 }) {
            this.Block('70%', 26, 8)
            this.Block('45%', 20, 8)
            this.Block('60%', 16, 8)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .padding(16)
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
        .height(200)
        .borderRadius(20)
        .backgroundColor(this.getCardColor())
        .backdropBlur(this.getCardBlur())
        .useEffect(true)

        // 简介卡片
        Column({ space: 12 }) {
          this.Block('100%', 18, 8)
          this.Block('92%', 18, 8)
          this.Block('80%', 18, 8)
          this.Block('55%', 18, 8)
        }
        .padding(16)
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .height(160)
        .borderRadius(20)
        .backgroundColor(this.getCardColor())
        .backdropBlur(this.getCardBlur())
        .useEffect(true)

        // 信息行卡片
        Column() {
          ForEach(this.rows, (index: number) => {
            Row() {
              this.Block(80, 18, 6)
              this.Block(120, 18, 6)
            }
            .height(48)
            .width('100%')
            .padding({ left: 16, right: 16 })
            .justifyContent(FlexAlign.SpaceBetween)
          }, (index: number) => index.toString())
        }
        .width('100%')
        .borderRadius(20)
        .backgroundColor(this.getCardColor())
        .backdropBlur(this.getCardBlur())
        .useEffect(true)
        // .divider({
        //   strokeWidth: 0.5,
        //   color: '#ffd6d4d4',
        //   startMargin: 10,
        //   endMargin: 10
        // })

        // 下载按钮占位
        Row()
          .width('100%')
          .height(55)
          .borderRadius(20)
          .backgroundColor(this.getCardColor())
          .backdropBlur(this.getCardBlur())
          .useEffect(true)
      }
      .width('100%')
      .padding({
        left: Math.max(16, __System__.leftRectHeight),
        right: Math.max(16, __System__.rightRectHeight)
      })
      .borderRadius({ topLeft: 20, topRight: 20 })
      .clip(true)
      .opacity(this.pulse)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPageBg())
    .align(Alignment.Top)
    .contentEndOffset(Math.max(__System__.bottomRectHeight, 16))
    .edgeEffect(EdgeEffect.Spring)
  }
}
