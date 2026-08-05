import { LFileKit, XAnimation, XContext } from "commonpackage"
import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationTitleMode,
  IconStyleMode
} from "@kit.UIDesignKit"
import { __BookSource__, __Setting__ } from "../../commons/shareDatas"
import { fileIo, fileUri, picker } from "@kit.CoreFileKit"
import { FileKit } from "../../models/classes/FileKit"
import { uri } from "@kit.ArkTS"
import { BookSourceParserArk } from "libohos_app_cangjie_entry.bookSource.so"

@Builder
export function SourceManagerSheetBuilder() {
  SourceManagerSheet()
}

@ComponentV2
export struct SourceManagerSheet {
  @Consumer('showAccountSourceSheet') showAccountSourceSheet: boolean = false
  pathStack: NavPathStack = new NavPathStack()

  build() {
    HdsNavigation(this.pathStack) {
      List({ space: 10 }) {
        ForEach(__BookSource__.parsers,(source:BookSourceParserArk, index: number)=>{
          ListItem(){
            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text(source.bookSource.bookSourceName)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(source.bookSource.bookSourceGroup == '' ? source.fileName : source.bookSource.bookSourceGroup)
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('sys.color.background_primary'))
            .borderRadius(16)
          }
        })
      }.height('100%')
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .size({ width: '100%', height: '100%' })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .backgroundColor($r('sys.color.background_tertiary'))
    .titleBar({
      enableComponentSafeArea: true, // 将标题栏设置为组件级安全区，内容区可避让标题栏
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        },
        scrollEffectOpts: {
          enableScrollEffect: false
        }
      },
      content: {
        title: {
          mainTitle: __Setting__.appWorkMode == 0 ? "账号管理" : "书源管理"
        },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.plus'),
                type: IconStyleMode.SMALL,
                componentId: "addSourceMenu",
                action: () => {
                  XContext.openMenu("addSourceMenu", wrapBuilder(addSourceMenu))
                }
              }
            },
            {
              content: {
                icon: $r('sys.symbol.xmark'),
                type: IconStyleMode.SMALL,
                action: () => {
                  this.showAccountSourceSheet = false;
                }
              }
            }
          ]
        }
      }
    })
    .hideToolBar(true)
  }
}

@Builder
function addSourceMenu() {
  Menu() {
    MenuItem({ content: '本地导入' }).onClick(() => {
      //创建Picker
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1
      documentSelectOptions.selectMode = picker.DocumentSelectMode.FILE;
      documentSelectOptions.fileSuffixFilters = ['书源(.json)|.json'];
      const documentViewPicker = new picker.DocumentViewPicker(XContext.getAbilityContext());
      documentViewPicker.select(documentSelectOptions).then(async (uris: string[]) => {
        let uri = uris[0]
        if (uri) {
          let spilt = uri.split('/')
          let fileName = spilt[spilt.length -1]
          let resUri =  fileUri.getUriFromPath(`${FileKit.bookSourcePath}/${fileName}`)
          //读取导入文件
          LFileKit.read(uri).then(async (json)=>{
            console.log(`meow:${json}`)
            let parser = new BookSourceParserArk(fileName,json)
            console.log(`meow:${parser.bookSource.bookSourceName}`)
            let conflict = __BookSource__.parsers.filter((item)=>item.fileName == fileName || item.bookSource.bookSourceName == parser.bookSource.bookSourceName ).length != 0
            if (conflict) {
              XContext.toast("请不要重复导入同名json或者重复的源")
            }else {
              let canAccess = await FileKit.createSourcePath()
              if (canAccess) {
                LFileKit.copy(uri, resUri).then((res)=>{
                  if (res) {
                    XContext.toast("导入成功")
                    __BookSource__.parsers.push(parser)
                  }else{
                    XContext.toast("导入失败")
                  }
                })
              }else {
                XContext.toast("导入失败,无法获取存储目录")
              }
            }
          })




        }


        // LFileKit.read(uris[0]).then((meow)=>{
        //   console.log(`meow:内容为:\n ${meow}`)
        //   let parser =  new BookSourceParserArk(meow)
        //   parser.search("我",undefined,(books)=>{
        //     books.forEach((book)=>{
        //       console.error("meow:"+book.name)
        //     })
        //   },(err)=>{
        //     console.error("meow:发生错误"+err)
        //   })
        // })

      }).catch((err: BusinessError) => {
        console.error(`meow 选取文件失败, code is ${err.code}, message is ${err.message}`);
      });
    })
    MenuItem({ content: '仓库导入' }).enabled(false)
  }
}
