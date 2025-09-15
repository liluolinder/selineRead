import { __System__, minWidth, __CustomBackgroundData__ } from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { fileUri } from "@kit.CoreFileKit"
import { globlContext } from "../../../entryability/EntryAbility"


@Builder
export function loadingDialog() {
  Stack() {
    Column({ space: 10 }) {
      LoadingProgress().size({ width: 100, height: 100 })
      Text('正在载入').fontSize(20).fontWeight(FontWeight.Medium)
    }.borderRadius(20).padding(20).backgroundColor($r('app.color.start_window_background_blur')).backdropBlur(100)
  }
  .size({ width: '100%', height: '100%' })
  .backgroundColor($r('sys.color.comp_background_tertiary'))
  .transition(TransitionEffect.OPACITY.animation({ curve: Curve.Ease, duration: 300 }))
  .zIndex(114514)
}

@Builder
export function loadingNewDialog() {
  Stack({ alignContent: Alignment.Bottom }) {
    Row({ space: 5 }) {
      LoadingProgress().size({ width: 35, height: 35 }).color($r('sys.color.font')).opacity(0.6)
      Text('正在载入').fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font')).opacity(0.6)
    }.padding(10).borderRadius(10).backdropBlur(100)
  }
  .size({ width: '100%', height: '100%' })
  .padding({ bottom: Math.max(16, __System__.bottomRectHeight + (__System__.windowWidth > minWidth ? 0 : 100)) })
  .enabled(false)
  .zIndex(114514)
  .transition(XAnimation.getAnimation('bottom'))
  .zIndex(114514)
}

@Builder
export function customBackground() {
  if (!__CustomBackgroundData__.refresh) {
    Stack() {
      Image(fileUri.getUriFromPath(globlContext.filesDir + '/background'))
        .size({ width: '100%', height: '100%' })
        .objectFit(ImageFit.Cover)
        .draggable(false)
        .autoResize(true)
        .transition(TransitionEffect.OPACITY.animation({ duration: 500, curve: Curve.Ease, delay: 400 }))

      Stack()//背景遮罩
        .backgroundColor('#' + __CustomBackgroundData__.darkness.toString(16).toUpperCase() + '000000')
        .blur(__CustomBackgroundData__.blur)
        .size({ width: '100%', height: '100%' })
        .animation({ duration: 300, curve: Curve.Ease })
    }
    .animation({ duration: 300, curve: Curve.Ease })
  }
}

@ComponentV2
export struct BookCover{
  @Param @Require data: ResourceStr|undefined
  @Param haveShadow: boolean = true
  @Local private  isFinish: boolean = false

  build() {
    Stack(){
      Image($r('app.media.default_cover')).aspectRatio(0.71).visibility(this.isFinish? Visibility.None: Visibility.Visible).animation({duration: 100}).draggable(false).objectFit(ImageFit.Cover)
      Image(this.data ?? $r('app.media.default_cover')).width('100%').visibility(this.isFinish? Visibility.Visible: Visibility.Hidden).animation({duration: 100}).draggable(false).objectFit(ImageFit.Contain)
        .onComplete(()=>{
          this.isFinish = true
        })
    }
    .reuseId(this.data?.toString())
    .shadow({
      radius: this.haveShadow? 25: 0,
      color: Color.Gray,
      offsetX: 0,
      offsetY: 10
    })
  }
}

