import { __System__, minWidth } from "../datas/classes/ShareDatas"
import { XAnimation } from "../datas/classes/XAnimation"


@Builder
export function loadingDialog(){
  Stack(){
    Column({space: 10}){
      LoadingProgress().size({width: 100, height: 100})
      Text('正在载入').fontSize(20).fontWeight(FontWeight.Medium)
    }.borderRadius(20).padding(20).backgroundColor($r('app.color.start_window_background_blur')).backdropBlur(100)
  }.size({width: '100%', height: '100%'}).backgroundColor($r('sys.color.comp_background_tertiary')).transition(TransitionEffect.OPACITY.animation({curve:Curve.Ease, duration: 300})).zIndex(114514)
}

@Builder
export function loadingNewDialog(){
  Stack({alignContent: Alignment.Bottom}){
    Row({space: 5}){
      LoadingProgress().size({width: 35, height: 35}).color($r('sys.color.font')).opacity(0.6)
      Text('正在载入').fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font')).opacity(0.6)
    }.padding(10).borderRadius(10).backdropBlur(100)
  }.size({width: '100%', height: '100%'}).padding({bottom: Math.max(16, __System__.bottomRectHeight + (__System__.windowWidth > minWidth? 0: 100))}).enabled(false)
  .transition(XAnimation.getAnimation('bottom'))
}