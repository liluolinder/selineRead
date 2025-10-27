import { XAnimation } from "commonpackage";
import { __System__ } from "../../main/ets/commons/shareDatas";
import { backgroundBlurModifier } from "../../main/ets/models/classes/backGroundEffect";

@Builder
export function BottomLoadingDialog(){
  Stack({alignContent: Alignment.Bottom}){
    Row({space: 10}){
      Text('正在加载').fontSize(20).fontColor($r('sys.color.font'))
      LoadingProgress().size({width: 20, height: 20}).color($r('sys.color.font'))
    }
    .padding({left: 15, right: 15, top: 10, bottom: 10})
    .borderRadius(10)
    .attributeModifier(backgroundBlurModifier)
    .margin({bottom: Math.max(16, __System__.bottomRectHeight)})
    .transition(XAnimation.getAnimation('bottom'))
    .shadow({
      color: $r('app.color.shadow_color'),
      radius: 35
    })
  }.size({width: '100%', height: '100%'})
}