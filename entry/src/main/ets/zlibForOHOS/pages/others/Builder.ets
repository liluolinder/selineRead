import { __System__, minWidth, __CustomBackgroundData__, __UI__,
  CustomBackgroundData,
  UIShareData} from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { fileUri } from "@kit.CoreFileKit"
import { globalContext } from "../../../entryability/EntryAbility"
import { ConfigurationConstant } from "@kit.AbilityKit"
import image from "@ohos.multimedia.image"


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

@ComponentV2
export struct CustomBackground{
  @Local private  customBackgroundData: CustomBackgroundData = __CustomBackgroundData__
  @Local private uiData: UIShareData = __UI__
  @Local private pixelMap: image.PixelMap|undefined
  @Local private imageOpacity: number = 0

  @Monitor('customBackgroundData.refresh', 'uiData.currentColorMode')
  async updateImage(){
    animateToImmediately({duration: 300, curve: Curve.Ease}, ()=> this.imageOpacity = 0)
    this.pixelMap = await image.createImageSource(this.customBackgroundData.customBackgroundFollowColorMode && this.uiData.currentColorMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK ?
      globalContext.filesDir + '/background_dark' : globalContext.filesDir + '/background')?.createPixelMap()
  }

  build() {
      Stack() {
        Image(this.pixelMap)
          .size({ width: '100%', height: '100%' })
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .autoResize(true)
          .opacity(this.imageOpacity)
          .onFinish(()=>{
            animateToImmediately({duration: 300, curve: Curve.Ease}, ()=> this.imageOpacity = 1)
          })


        Stack()//背景遮罩
          .backgroundColor('#' + this.customBackgroundData.darkness.toString(16).toUpperCase() + '000000')
          .blur(this.customBackgroundData.blur)
          .size({ width: '100%', height: '100%' })
          .animation({ duration: 300, curve: Curve.Ease })
      }
      .animation({ duration: 300, curve: Curve.Ease })
  }
}

@Builder
export function customBackground() {

}

@ComponentV2
export struct BookCover{
  @Param @Require data: ResourceStr|undefined
  @Param haveShadow: boolean = true
  @Param imageFit:ImageFit = ImageFit.Contain
  @Local private isFinish: boolean = false

  build() {
    Stack(){
      Image($r('app.media.default_cover')).aspectRatio(0.71).visibility(this.isFinish? Visibility.None: Visibility.Visible).animation({duration: 100}).draggable(false).objectFit(ImageFit.Cover)
      Image(this.data ?? $r('app.media.default_cover')).visibility(this.isFinish? Visibility.Visible: Visibility.Hidden).animation({duration: 100}).draggable(false).objectFit(this.imageFit)
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

