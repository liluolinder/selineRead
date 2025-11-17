import { __CustomBackgroundData__ } from "../../components/CustomBackground"

@ComponentV2
export struct EmptyPage {
  @Local pageOpacity: number = 0

  build() {
    NavDestination() {
      Stack() {
        Image($r('app.media.zlib')).constraintSize({maxWidth: '40%', maxHeight: '40%'}).draggable(false).opacity(0.5).aspectRatio(1)
      }.size({ width: '100%', height: '100%' })
    }
    .backgroundColor(__CustomBackgroundData__.customBackground ? Color.Transparent :
    $r('sys.color.comp_background_gray'))
    .opacity(this.pageOpacity)
    .onShown(() => {
      animateToImmediately({ duration: 500, curve: Curve.Ease }, () => {
        this.pageOpacity = 1
      })
    })
    .onWillHide(() => {
      animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
        this.pageOpacity = 0
      })
    })
  }
}

@Builder
export function emptyPageBuilder() {
  EmptyPage()
}