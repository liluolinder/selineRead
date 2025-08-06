import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { __System__ } from '../datas/classes/ShareDatas'
import WindowsUtil from '../utils/WindowsUtil'

@ComponentV2
export struct DecorBar {
  @Local isTop: boolean = false
  isClicked: boolean = false

  click() {
    if (this.isClicked) {
      try {
        if (__System__.windowState == window.WindowStatusType.FULL_SCREEN ||
          __System__.windowState == window.WindowStatusType.MAXIMIZE) {
          WindowsUtil.getWindowClass()?.recover()
        } else {
          WindowsUtil.getWindowClass()?.maximize(window.MaximizePresentation.EXIT_IMMERSIVE)
        }
      } catch {
      }
      this.isClicked = false
    } else {
      this.isClicked = true
      setTimeout(() => {
        this.isClicked = false
      }, 300)
    }
  }

  build() {
      Stack() {
        Flex({
          justifyContent: FlexAlign.SpaceBetween,
          alignItems: ItemAlign.Center
        }) {
          Row({ space: 10 }) {
            Image($r('app.media.zlib')).size({ height: 30, width: 30 }).borderRadius(5).draggable(false)
            Text($r('app.string.app_name')).fontSize(16).fontWeight(FontWeight.Medium)
          }


          Row({ space: 10 }) {
            DecorBarButton({
              //置顶
              symbol: this.isTop ? $r('sys.symbol.pin_fill') : $r('sys.symbol.pin'),
              symbolColor: $r('sys.color.font'),
              symbolColorSelected: $r('sys.color.font'),
              buttonColorSelected: $r('sys.color.comp_background_tertiary'),
              symbolSize: 20,
              buttonSize: 30
            })
              .onClick(() => {
                WindowsUtil.getWindowClass()?.setWindowTopmost(!this.isTop)
                this.isTop = !this.isTop
              })


            DecorBarButton({
              //最大化
              symbol: __System__.windowState == window.WindowStatusType.FULL_SCREEN ||
                __System__.windowState == window.WindowStatusType.MAXIMIZE ?
              $r('sys.symbol.arrow_down_right_and_arrow_up_left') : $r('sys.symbol.arrow_up_left_and_arrow_down_right'),
              symbolColor: $r('sys.color.font'),
              symbolColorSelected: $r('sys.color.font'),
              buttonColorSelected: $r('sys.color.comp_background_tertiary'),
              symbolSize: 17,
              buttonSize: 30
            })
              .onClick(() => {
                try {
                  if (__System__.windowState == window.WindowStatusType.FULL_SCREEN ||
                    __System__.windowState == window.WindowStatusType.MAXIMIZE) {
                    WindowsUtil.getWindowClass()?.recover()
                  } else {
                    WindowsUtil.getWindowClass()?.maximize(window.MaximizePresentation.EXIT_IMMERSIVE)
                  }
                } catch {
                }
              })

            DecorBarButton({
              //最小化
              symbol: $r('sys.symbol.line'),
              symbolColor: $r('sys.color.font'),
              symbolColorSelected: $r('sys.color.font'),
              buttonColorSelected: $r('sys.color.comp_background_tertiary'),
              symbolSize: 19,
              buttonSize: 30
            })
              .onClick(() => {
                try {
                  WindowsUtil.getWindowClass()?.minimize()
                } catch {
                }
              })

            DecorBarButton({
              //关闭
              symbol: $r('sys.symbol.xmark'),
              symbolColor: $r('sys.color.warning'),
              symbolColorSelected: Color.White,
              buttonColorSelected: $r('sys.color.warning'),
              symbolSize: 20,
              buttonSize: 30
            })
              .onClick(() => {
                (getContext() as common.UIAbilityContext).terminateSelf()
              })
          }

        }
        .size({ width: '100%', height: __System__.topRectHeight })
        .padding({ left: 20, right: 20 })

      }
      .onClick(() => {
        this.click()
      })
      .onMouse((event) => {
        if (event.button == MouseButton.Left && event.action == MouseAction.Press) {
          this.click()
        }
      })
  }
}


@ComponentV2
struct DecorBarButton {
  @Param @Require buttonSize: number
  @Param @Require symbol: Resource
  @Param @Require symbolColor: ResourceStr | Color
  @Param @Require symbolSize: number
  @Param @Require symbolColorSelected: ResourceStr | Color
  @Param @Require buttonColorSelected: ResourceStr | Color
  @Local isHover: boolean = false

  build() {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      SymbolGlyph(this.symbol)
        .fontSize(this.symbolSize)
        .fontColor([this.isHover ? this.symbolColorSelected : this.symbolColor])
        .translate({ z: this.isHover ? 50 : 0 })
    }
    .size({ width: this.buttonSize, height: this.buttonSize })
    .borderRadius(this.buttonSize / 8)
    .backgroundColor(this.isHover ? this.buttonColorSelected : Color.Transparent)
    .onHover((isHover) => {
      animateToImmediately({ duration: 200, curve: Curve.Ease }, () => this.isHover = isHover)
    })
    .onTouch((event) => {
      if (event.type == TouchType.Down) {
        animateToImmediately({ duration: 200, curve: Curve.Ease }, () => this.isHover = true)
      } else if (event.type == TouchType.Up || event.type == TouchType.Cancel) {
        setTimeout(() => {
          animateToImmediately({ duration: 200, curve: Curve.Ease }, () => this.isHover = false)
        }, 100)
      }
    })
  }
}