import { BasicDataSource, XAnimation } from "commonpackage"
import { __System__ } from "../../../commons/shareDatas"
import { __CustomBackgroundData__ } from "../../../components/CustomBackground"
import { ComposeTitleBar, SymbolGlyphModifier } from "@kit.ArkUI"

@ObservedV2
export class BookShelfData{
  bookList: BasicDataSource<string> =
    new BasicDataSource<string>()

}

export let __BookShelf__:BookShelfData = new BookShelfData()

@ComponentV2
export struct BookShelf{
  build() {
   Column(){
     Navigation(){
       List({space:10}){
         LazyForEach(__BookShelf__.bookList,(item:string, index:number)=>{
           ListItem(){
             Column(){
               Text(item)
                 .width('100%')
             }.height(100)
           }.padding(16)
           .backgroundColor($r('sys.color.comp_background_list_card'))
           .borderRadius(20)
           .transition(XAnimation.getAnimation('bottom'))
         })
       }.height('100%')
       .width('100%')
       .padding({left:16, right:16})
       .borderRadius(20)
       .contentEndOffset(16)
     }.size({width:'100%', height:'100%'})
     .title($r('app.string.Title_BookShelf'))
     .hideToolBar(true)
     .hideBackButton(true)
     .mode(NavigationMode.Stack)
     .menus([
       {
         value: 'downloadPage',
         symbolIcon: new SymbolGlyphModifier($r('sys.symbol.download')),
         action: () => {
         }
       }
     ])
   }.padding({top:Math.max(16,__System__.topRectHeight)})
  }
}