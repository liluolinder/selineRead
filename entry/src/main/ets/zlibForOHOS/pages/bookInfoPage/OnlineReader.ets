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
      Column() {
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