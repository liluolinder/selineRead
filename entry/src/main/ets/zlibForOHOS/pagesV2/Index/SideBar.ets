import { I_PageInfo } from "../../datas/interfaces/I_PageInfo";
import { ImageModifier, LengthUnit } from "@kit.ArkUI";
import { min_width, __System__, __UI__, __User__ } from "../../datas/classes/ShareDatas";
import { zlibClient } from "../../datas/classes/zlib";
import { ListItemWithArrow } from "../../components/ListItemWithArrow";
import { XAnimation } from "../../datas/classes/XAnimation";
import { backgroundBlurModifier } from "../../datas/classes/backGroundEffect";

@ComponentV2
export struct SideBar {
  @Consumer('tabController') tabController: TabsController = new TabsController();
  @Consumer('currentTabIndex') currentTabIndex: number = 0
  @Local showLoginOrUserInfo: boolean = false
  pageArray: I_PageInfo[] = [
    { name: '推荐视频', symbol: $r('sys.symbol.wand_and_stars') },
    { name: '历史观看', symbol: $r('sys.symbol.clock') },
    { name: '收藏集', symbol: $r('sys.symbol.rectangle') },

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

              if (zlibClient.userInfo?.avatar) {
                Image(zlibClient.userInfo?.avatar)
                  .width(80)
                  .height(80)
                  .borderRadius(40)
                  .attributeModifier(__UI__.isLargeSidebar ? this.avatarModifier_Large :
                  this.avatarModifier_Small)
              } else {
                Stack() {
                  SymbolGlyph($r('sys.symbol.person')).opacity(0.5).fontColor([$r('sys.color.font')]).fontSize(40)
                }.backgroundColor($r('sys.color.comp_background_gray'))
                .width(80)
                .height(80)
                .borderRadius(40)

              }


            }


          }
          .borderRadius(20)
          .padding(__UI__.isLargeSidebar ? 12 : 0)
          .width('100%')
          .height(__UI__.isLargeSidebar? 100: 'auto')
          .onClick(() => {
            this.showLoginOrUserInfo = true
          })
          .backgroundColor($r('sys.color.comp_background_primary'))



          Column({ space: __UI__.isLargeSidebar ? 0 : 10 }) {
            ForEach(this.pageArray, (item: I_PageInfo, index: number) => {
              ListItemWithArrow({
                symbol: item.symbol,
                image: item.image,
                message: item.name,
                isLarge: __UI__.isLargeSidebar,
                isHighlight: this.currentTabIndex == index,
                hasBackground: !__UI__.isLargeSidebar
              })
                .onClick(() => {
                  this.tabController.changeIndex(index)
                })
            })
          }
          .borderRadius(20)
          .width('100%')
          .backgroundColor(__UI__.isLargeSidebar? $r('sys.color.comp_background_primary'): Color.Transparent)

        }
      }
      .fadingEdge(true)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
      .width('100%')
      .layoutWeight(1)
      .clip(true)

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
          message: '设置',
          isLarge: __UI__.isLargeSidebar,
          hasBackground: true,
          showArrow: true
        })
          .layoutWeight(__UI__.isLargeSidebar ? 1 : 0)
          .onClick(() => {

          })

      }.height('auto')

    }.size({ height: '100%', width: '100%' })
    .padding({
      top: Math.max(__System__.topRectHeight, 10),
      left: __UI__.isLargeSidebar ? 16 : 12,
      right: __UI__.isLargeSidebar ? 16 : 12,
      bottom: __UI__.isLargeSidebar ? Math.max(__System__.bottomRectHeight, 10) : 10
    })
    .attributeModifier(backgroundBlurModifier)

  }
}