import { XAnimation } from 'commonpackage'

/**
 * BookInfo 页"类似书籍"区域骨架屏：与主体骨架屏分离，
 * 仅在主体 bookInfo 加载完成、similarBook 异步拉取期间显示。
 * 布局与 HomeBookCover 网格保持一致（每行列数随宽度自适应，
 * 同 BookInfo 的 tileColumnNumber + onAreaChange 模式），并带呼吸式闪烁动画。
 */
@ComponentV2
export struct SimilarBookSkeleton {
  @Local private pulse: number = 0.5
  @Local private rows: number[] = [0, 1]
  @Local private columns: number[] = [0, 1]

  aboutToAppear(): void {
    XAnimation.skeletonAnimation(()=>{
      this.pulse = 1
    })
  }

  private updateColumns(width: number) {
    let columnNumber = Math.max(Math.ceil(width / 240), 2)
    let cols: number[] = []
    for (let i = 0; i < columnNumber; i++) {
      cols.push(i)
    }
    this.columns = cols
  }

  @Builder
  private CoverCard() {
    Column({ space: 10 }) {
      Row()
        .width('100%')
        .aspectRatio(2 / 3)
        .borderRadius(15)
        .backgroundColor($r('sys.color.comp_background_tertiary'))

      Column({ space: 6 }) {
        Row()
          .width('85%')
          .height(16)
          .borderRadius(8)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
        Row()
          .width('55%')
          .height(12)
          .borderRadius(8)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .padding(16)
    .borderRadius(20)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .layoutWeight(1)
  }

  build() {
    Column({ space: 10 }) {
      ForEach(this.rows, (rowIndex: number) => {
        Row({ space: 20 }) {
          ForEach(this.columns, (colIndex: number) => {
            this.CoverCard()
          }, (colIndex: number) => colIndex.toString())
        }
        .width('100%')
      }, (rowIndex: number) => rowIndex.toString())
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .opacity(this.pulse)
    .onAreaChange((_, newValue) => {
      this.updateColumns(new Number(newValue.width).valueOf())
    })
  }
}
