import { XAnimation } from "commonpackage"
import { min_width } from "../commons/commonItem"
import { __System__ } from "../commons/shareDatas"

@Builder
export function loadingNewDialog() {
  Stack({ alignContent: Alignment.Bottom }) {
    Row({ space: 5 }) {
      LoadingProgress().size({ width: 35, height: 35 }).color($r('sys.color.font')).opacity(0.6)
      Text($r('app.string.Tip_GettingBookNow')).fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font')).opacity(0.6)
    }.padding(10).borderRadius(10).backdropBlur(100)
  }
  .size({ width: '100%', height: '100%' })
  .padding({ bottom: Math.max(16, __System__.bottomRectHeight + (__System__.windowWidth > min_width ? 0 : 100)) })
  .enabled(false)
  .zIndex(114514)
  .transition(XAnimation.getAnimation('bottom'))
  .zIndex(114514)
}

@Builder
export function loadingDialog() {
  Stack() {
    Column({ space: 10 }) {
      LoadingProgress().size({ width: 100, height: 100 })
      Text($r('app.string.Tip_GettingBookNow')).fontSize(20).fontWeight(FontWeight.Medium)
    }.borderRadius(20).padding(20).backgroundColor($r('app.color.start_window_background_blur')).backdropBlur(100)
  }
  .size({ width: '100%', height: '100%' })
  .transition(TransitionEffect.OPACITY.animation({ curve: Curve.Ease, duration: 300 }))
  .zIndex(114514)
}

