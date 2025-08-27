import { __System__ } from "../../datas/classes/ShareDatas"

@Builder
export function downloadPageBuilder(){
  DownloadPage()
}

@ComponentV2
struct DownloadPage{

  build() {
    NavDestination(){

    }.padding({top: __System__.topRectHeight})
    .title('下载任务')
    .backgroundColor($r('sys.color.comp_background_gray'))
  }
}