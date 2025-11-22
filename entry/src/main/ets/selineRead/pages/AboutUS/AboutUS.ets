import { LiqD, ListItemWithArrow } from "templatecomponent"
import { bundleManager } from "@kit.AbilityKit"
import { XAnimation, XContext } from "commonpackage"

@Builder
export function AboutUsBuilder() {
  AboutUS()
}

@ComponentV2
export struct AboutUS {
  pathStack:NavPathStack = new NavPathStack()
  itemArray:ResourceStr[]=[
    $r('app.string.Title_VersionInfo'),
    $r('app.string.Title_Appreciation'),
    $r('app.string.Title_Acknowledgments'),
    $r('app.string.Title_Meow'),
  ]
  @Local showZZ:boolean = false

  @Builder
  zzPageBuilder() {
    Column({ space: 10 }) {
      Text('注意:该赞助是对开发者的赞助，不是zlib的赞助，不会增加你的下载额度，不会在账号页面显示您的赞助额度（仅显示赞助zlib的额度）')
      Image($r('app.media.zfm'))
        .width(300)
    }.size({ width: '100%', height: '100%' })
    .padding({ left: 16, right: 16 })
  }

  build() {
    Navigation(this.pathStack){
      List({space:10}) {
        ListItem() {
          Column() {
            Image($r('app.media.zlib'))
              .aspectRatio(1)
              .draggable(false)
              .objectFit(ImageFit.Contain)
              .height(68)
            Text($r('app.string.EntryAbility_label'))
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('[color].color.linder_blue'))
              .opacity(0.9)
              .maxLines(1)
              .margin({ top: 5 })
            Column({ space: 5 }) {
              Text(bundleManager.getBundleInfoForSelfSync(0).versionName)
                .fontSize(18)
                .opacity(0.6)
                .fontWeight(FontWeight.Normal)
                .fontColor($r('[color].color.pixelartisan_blue'))
                .maxLines(1)
              Text(`(${bundleManager.getBundleInfoForSelfSync(0).versionCode})`)
                .fontSize(12)
                .opacity(0.6)
                .fontColor($r('[color].color.pixelartisan_blue'))
                .maxLines(1)
            }
          }.backgroundColor($r('sys.color.comp_background_list_card'))
          .width('100%')
          .borderRadius(20)
          .padding(8)
        }.transition(XAnimation.getAnimation('bottom',0))

        ForEach(this.itemArray,(item:ResourceStr,index:number)=>{
          ListItemWithArrow({
            message:item,
          })
            .borderRadius(20)
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .transition(XAnimation.getAnimation('bottom',(index+1)*50))
            .onClick(()=>{
                switch (index) {
                  case 0:
                    this.pathStack.pushPathByName("VersionInfo",null)
                    break;
                  case 1:
                    this.showZZ=true
                    break;
                  case 2:
                    this.pathStack.pushPathByName("Acknowledgments",null)
                    break;
                  case 3:
                    XContext.getAbilityContext().startAbility({
                      uri: 'https://www.chuckfang.com/MeoW/appLinking?channelId=c2ba80556f0c469faa03b98c7a44f933'
                    })
                    break;
                }
            })
        })

        ListItem() {
          LiqD()
        }.clip(true)
        .transition(XAnimation.getAnimation('bottom',250))



      }.width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom:16 })
      Column(){
        Blank()
          .bindSheet($$this.showZZ, this.zzPageBuilder(), {
            preferType: SheetType.CENTER,
            title: { title: '赞助开发者', subtitle: '您的赞助，我们的动力(^~^)' },
            height: SheetSize.MEDIUM,
          })
      }
    }
    .size({width:'100%', height:'100%'})
    .backgroundColor($r('sys.color.background_tertiary'))
    .hideTitleBar(true)
    .hideToolBar(true)
  }
}