import { ListItemWithArrow } from "templatecomponent"

@Builder
export function AccountManagerBuilder(){
  AccountManager()
}


@ComponentV2
export struct AccountManager{

  pathStack:NavPathStack = new NavPathStack()

  build() {
    Navigation(this.pathStack){
      Column(){
        List(){
          ListItemWithArrow({
            image:$r('app.media.zlibrary'),
            message:'Z-library',
          })
            .onClick(()=>{
              this.pathStack.pushPathByName("ZlibraryAccount",null)
            })

        }.height('100%')
        .width('100%')
        .padding({left:16, right:16})
      }.size({width:'100%', height:'100%'})
    }.size({width:'100%', height:'100%'})
    .backgroundColor($r('sys.color.background_tertiary'))
    .hideTitleBar(true)
    .hideToolBar(true)
  }
}

