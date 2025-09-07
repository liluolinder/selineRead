import { __System__, __UI__ } from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { webview } from "@kit.ArkWeb";
import { zlibClient } from "../../datas/classes/zlib";

@Builder
export function onlineReaderBuilder(){
  OnlineReader()
}


@ComponentV2
struct OnlineReader{

  controller: webview.WebviewController = new webview.WebviewController();
  url: string = ''


  build() {
    NavDestination(){
      Stack({alignContent: Alignment.TopStart}) {
        Web({ src: '', controller: this.controller })
          .height('100%')
          .height('100%')
          .javaScriptAccess(true)
          .cacheMode(CacheMode.Default)
          .allowWindowOpenMethod(true)
          .domStorageAccess(true)
          .databaseAccess(true)
          .fileAccess(true)
          .mixedMode(MixedMode.Compatible)
          .darkMode(WebDarkMode.Auto)
          .onAppear(()=>{
            zlibClient.cookie.split('; ').forEach((cookie)=>{
              webview.WebCookieManager.configCookieSync(this.url, cookie)
            })
            this.controller.loadUrl(this.url)
          })

        if(__System__.pcMode){
          Button(){
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(30)
          }.backgroundColor($r('app.color.start_window_background')).size({width: 40, height: 40})
          .margin(10)
          .opacity(0.7)
          .onClick(()=>{
            __UI__.HomePageStack.pop()
          })
        }

      }.size({width:'100%', height:'100%'})
    }.onWillAppear(()=> {
      XAnimation.runWithAnimation(() => __UI__.isInReader = true)
    })
    .hideTitleBar(true)
    .padding({top: __System__.topRectHeight})
    .onWillDisappear(()=> {
      XAnimation.runWithAnimation(() => __UI__.isInReader = false)
    })
    .onReady((context: NavDestinationContext) => {
      this.url = context.pathInfo.param as string
    })
  }
}