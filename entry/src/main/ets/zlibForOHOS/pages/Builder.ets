

@Builder
export function loadingDialog(){
  Stack(){
    Column({space: 10}){
      LoadingProgress().size({width: 100, height: 100})
      Text('正在载入').fontSize(20).fontWeight(FontWeight.Medium)
    }.borderRadius(20).padding(20).backgroundColor($r('app.color.start_window_background_blur')).backdropBlur(100)
  }.size({width: '100%', height: '100%'}).backgroundColor($r('sys.color.comp_background_tertiary')).transition(TransitionEffect.OPACITY.animation({curve:Curve.Ease, duration: 300})).zIndex(114514)
}