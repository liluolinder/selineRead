import { I_PageInfo } from "../../models/interfaces/I_PageInfo";
import { ImageModifier, LengthUnit } from "@kit.ArkUI";
import { __System__, __UI__, __ZlibUser__ } from "../../commons/shareDatas";
import { ListItemWithArrow } from "templatecomponent";
import { min_width } from "../../commons/commonItem";
import { XAnimation } from "commonpackage";
import { ConfigurationConstant } from "@kit.AbilityKit";
import { backgroundBlurModifier } from "../../models/classes/backGroundEffect";
import { AccountManagerBuilder } from "../zlibrary/AccountManager/AccountManager";
import { SettingBuilder } from "../zlibrary/Setting/Setting";
import { AboutUsBuilder } from "../AboutUS/AboutUS";


@ComponentV2
export struct SideBar {
  @Consumer('tabController') tabController: TabsController = new TabsController();
  @Consumer('currentTabIndex') currentTabIndex: number = 0
  @Provider('showLoginOrUserInfo') showLoginOrUserInfo: boolean = false
  @Provider("showSetting") showSetting:boolean = false
  @Provider("showAboutUs") showAboutUs:boolean = false
  @Local showAccountManager:boolean = false

  pageArray: I_PageInfo[] = [
    { name: $r('app.string.Title_Home'), symbol: $r('sys.symbol.house') },
    { name: $r('app.string.Title_BookShelf'), symbol: $r('sys.symbol.book_closed_right_left') },
  ]
  avatarModifier_Large: ImageModifier = new ImageModifier().height(75).width(75).borderRadius(1000).draggable(false)
  avatarModifier_Small: ImageModifier =
    new ImageModifier().size({ width: '100%' }).aspectRatio(1).borderRadius(1000).clip(true)

  build() {
    Column({ space: 10 }) {
      Scroll() {
        Column({ space: 10 }) {
          Row({ space: 12 }) {
            Stack() {
              Image(__ZlibUser__.avatar==''?$r('app.media.zlib'):__ZlibUser__.avatar)
                .attributeModifier(__UI__.isLargeSidebar ? this.avatarModifier_Large :
                  this.avatarModifier_Small)
            }

            if (__UI__.isLargeSidebar) {
              if (__ZlibUser__.account != '') {
                Column({ space: 2 }) {
                  Text(__ZlibUser__.userName??'未命名')
                    .fontWeight(FontWeight.Bold)
                    .fontSize(20)
                    .textAlign(TextAlign.Center)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.MARQUEE })
                    .layoutWeight(1)
                }.alignItems(HorizontalAlign.Start)
                .height(24)
                .layoutWeight(1)
                .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: -100 })))
              } else {
                Text('请先登录')
                  .fontWeight(FontWeight.Bold)
                  .fontSize(20)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
              }

            }
          }

          .borderRadius(20)
          .padding(__UI__.isLargeSidebar ? 12 : 0)
          .width('100%')
          .height(100)
          .onClick(() => {
            this.showAccountManager = true
          })
          .bindSheet($$this.showAccountManager, AccountManagerBuilder() , {
            title:{title:$r('app.string.Title_AccountManager')},
            preferType:SheetType.CENTER,
            height:SheetSize.LARGE,
            backgroundColor:$r('sys.color.background_tertiary')
          })


          Column({ space: __UI__.isLargeSidebar ? 0 : 10 }) {
            ForEach(this.pageArray, (item: I_PageInfo, index: number) => {
              ListItemWithArrow({
                symbol: item.symbol,
                image: item.image,
                message: item.name,
                isLarge: __UI__.isLargeSidebar,
                isHighlight: this.currentTabIndex == index
              })
                .onClick(() => {
                  this.tabController.changeIndex(index)
                  if (__System__.windowWidth < min_width) {
                    XAnimation.runWithAnimation(() => {
                      __UI__.isShowSideBar = false
                    })
                  }
                  if (this.currentTabIndex != index) {
                    switch (index) {
                      case 0:
                        //__Client__.getRecentSong(true)
                        break
                      case 1:
                        break
                      case 2:
                        break
                    }
                  }
                })
            })
          }
          .borderRadius(20)
          .width('100%')
          .backgroundColor(Color.Transparent)

        }
      }
      .fadingEdge(true)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
      .width('100%')
      .layoutWeight(1)
      .clip(true)

      Column({space:10}){

        if (__System__.windowHeight>450) {
          ListItemWithArrow({
            symbol: $r('sys.symbol.info_circle'),
            message: $r('app.string.Title_AboutUS'),
            isLarge: __UI__.isLargeSidebar,
            hasBackground: true,
            showArrow: true
          })
            .onClick(()=>{
              this.showAboutUs = true
            })
            .bindSheet($$this.showAboutUs,AboutUsBuilder(),{
              preferType:SheetType.CENTER,
              height:SheetSize.LARGE,
              title:{title:$r('app.string.Title_AboutUS')},
              backgroundColor:$r('sys.color.background_tertiary')
            })
        }

        Flex({
          direction: __UI__.isLargeSidebar ? FlexDirection.Row : FlexDirection.ColumnReverse,
          space: { main: { value: 10, unit: LengthUnit.VP } }
        }) {
          if (__System__.windowWidth > min_width) {
            ListItemWithArrow({
              symbol: __UI__.isLargeSidebar ? $r('sys.symbol.open_sidebar') : $r('sys.symbol.close_sidebar'),
              isLarge: false,
              hasBackground: true,
              showArrow: false
            })
              .onClick(() => {
                XAnimation.runWithAnimation(() => {
                  __UI__.isLargeSidebar = !__UI__.isLargeSidebar
                })
              }).height(__UI__.isLargeSidebar ? 55 : 'auto')
              .width(__UI__.isLargeSidebar ? 55 : '100%')

          }

          ListItemWithArrow({
            symbol: $r('sys.symbol.gearshape'),
            message: $r('app.string.Title_Setting'),
            isLarge: __UI__.isLargeSidebar,
            hasBackground: true,
            showArrow: true
          })
            .layoutWeight(__UI__.isLargeSidebar ? 1 : 0)
            .onClick(() => {
              this.showSetting = true
            })
            .bindSheet($$this.showSetting,SettingBuilder(),{
              preferType:SheetType.CENTER,
              height:SheetSize.LARGE,
              title:{title:$r('app.string.Title_Setting')},
              backgroundColor:$r('sys.color.background_tertiary')
            })
        }.height('auto')
      }.height('auto')

    }.size({ height: '100%', width: '100%' })
    .attributeModifier(backgroundBlurModifier)
    .padding({
      top: Math.max(__System__.topRectHeight, 10),
      left: __UI__.isLargeSidebar ? 16 : 12,
      right: __UI__.isLargeSidebar ? 16 : 12,
      bottom: __UI__.isLargeSidebar ? Math.max(__System__.bottomRectHeight, 10) : 10
    })

  }
}