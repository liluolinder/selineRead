import { I_openSource } from "../../models/interfaces/I_openSource"
import { Want } from "@kit.AbilityKit"
import { XContext } from "commonpackage"

@Builder
export function OpenSourceBuilder(){
  OpenSource()
}

@ComponentV2
export struct OpenSource{

  @Local projects:I_openSource[]=[
    {
      projectName:'LinderHttp',
      url:'https://gitcode.com/LiquidStudio/LinderHttp',
      license:'MulanPSL2'
    },
    {
      projectName:'zlibraryAPI4CJ',
      url:'https://gitcode.com/LiquidStudio/zlibraryAPI4CJ',
      license:'MulanPSL2'
    },
    {
      projectName:'selineDownload',
      url:'https://gitcode.com/LiquidStudio/selineDownload',
      license:'MulanPSL2'
    },
    {
      projectName:'selineWebdav',
      url:'https://gitcode.com/LiquidStudio/selineWebdav',
      license:'MulanPSL2'
    },
    {
      projectName:'ignite',
      url:'https://gitcode.com/cinyu/ignite-cangjie',
      license:'Apache-2.0'
    },
  ]

  build() {
    NavDestination(){
      List({space:10}){
        ForEach(this.projects,(item:I_openSource)=>{
          ListItem(){
            Column({space:10}){
              Text()
              {
                Span($r('app.string.Text_ProjectName'))
                Span(":")
                Span(item.projectName)
              } .width('100%')
                .maxLines(1)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .textOverflow({overflow:TextOverflow.MARQUEE})

              Text()
              {
                Span($r('app.string.Text_ProjectLicense'))
                Span(":")
                Span(item.license)
              }.width('100%')
                .maxLines(2)
                .fontSize(16)
                .fontWeight(FontWeight.Normal)

              Row(){
                Button({type:ButtonType.Capsule}){
                  Text($r('app.string.Text_GoTo'))
                }.padding(8)
                .width(100)
                .backgroundColor($r('sys.color.button_background_color_transparent'))
                .onClick(()=>{
                  let want: Want = {
                    action: 'ohos.want.action.viewData',
                    entities: ['entity.system.browsable'],
                    uri: item.url,
                  };
                  XContext.getAbilityContext().startAbility(want)
                })

              }.width('100%')



            }.size({ width: '100%'})
            .padding(16)
            .borderRadius(20)
            .backgroundColor($r('sys.color.comp_background_list_card'))
          }
        })
      }.height('100%')
      .width('100%')
      .chainAnimation(true)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollSnapAlign(ScrollSnapAlign.START)
      .scrollBar(BarState.Off)
      .padding({left:16, right:16, bottom:16})
    }.size({ width: '100%', height: '100%' })
    .backgroundColor($r('sys.color.background_tertiary'))
    .title($r('app.string.Title_OpenSourceReferences'))
  }
}