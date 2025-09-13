/*
Copyright (c) 2025 琉离铟落linder
SelineRead is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan
PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details.

Mulan Permissive Software License，Version 2

Mulan Permissive Software License，Version 2 (Mulan PSL v2)

January 2020 http://license.coscl.org.cn/MulanPSL2
 */

import { zlibClient } from '../../datas/classes/zlib'
import { I_RecommendBook } from '../../datas/interfaces/I_RecommendBook'
import { Chip, ChipSize, curves, LengthMetrics } from '@kit.ArkUI'
import { __CustomBackgroundData__, __System__, __UI__, minWidth, __User__ } from '../../datas/classes/ShareDatas'
import { XAnimation } from '../../datas/classes/XAnimation'
import { I_searchBook } from '../../datas/interfaces/I_BookInfo'
import { zlibIndexShowMod } from '../../datas/enums/zlibIndexShowMod'
import { loadingDialog, loadingNewDialog } from '../others/Builder'
import { addLog, setContinueState } from '../../utils/ToolsUtil'
import { scanBarcode, scanCore } from '@kit.ScanKit'
import { globlContext } from '../../../entryability/EntryAbility'
import { BusinessError } from '@kit.BasicServicesKit'
import { JSON } from '@kit.ArkTS'
import { ListItemWithText } from '../others/ListItem'
import { formatArray, languageArray, timeArray } from '../../datas/commons/zlibSearchOption'
import { I_KV } from '../../datas/interfaces/I_KV'
import { I_SearchHistory } from '../../datas/interfaces/I_SearchHistory'
import NeoPreferencesUtil from '../../datas/classes//XPreferencesUtil'

@ComponentV2
export struct zlibHome {
  @Local showSearchPage: boolean = false
  @Local listOrWaterFlow: zlibIndexShowMod = zlibIndexShowMod.WaterFlow
  @Local searchBookName: string = ''
  @Local waterFlowColumnNumber: number = -1
  @Local waterFlowEmptyItem: number[] = []
  @Local isFlashing: boolean = false
  @Local isInScroller: boolean = false
  @Local isHaveGoToTop: boolean = false
  @Local searchBarOffsetY: number = 0
  @Local SideButtonOffsetX: number = 16
  @Local lastOffset: number = 0
  @Local scrollerOffset: number = 0
  @Local showSearchOption: boolean = false
  @Local scrollerController: Scroller = new Scroller()
  @Local startTime: string | undefined
  @Local startTImeIndex: number | number[] = 0;
  @Local endTIme: string | undefined
  @Local endTImeIndex: number | number[] | undefined;
  @Local showLanguagePopup: boolean = false
  @Local chooseLanguageArray: string[] = []
  @Local showFormatPopup: boolean = false
  @Local chooseFormatArray: string[] = []
  @Local searchType: number = 0

  @Monitor('lastOffset')
  changeOffset() {
    if (this.lastOffset > 0) {
      XAnimation.runWithAnimation(() => {
        this.searchBarOffsetY = -100
        this.SideButtonOffsetX = -60
      })
    } else if (this.lastOffset < 0) {
      XAnimation.runWithAnimation(() => {
        this.searchBarOffsetY = 0
        this.SideButtonOffsetX = 16
      })
    }

  }

  generateUrl(): string {
    let res: string = ''
    let tempRes: string = ''
    if ((this.startTime == undefined || this.startTime == '任何' ? -1 : Number(this.startTime)) >=
      (this.endTIme == undefined || this.endTIme == '任何' ? -1 : Number(this.endTIme))) {
      if (this.startTime != undefined && this.startTime != '任何') {
        res += `yearFrom=${this.startTime}`
      }
    } else if ((this.startTime == undefined || this.startTime === '任何') && this.endTIme !== '任何' &&
      (this.endTIme != undefined)) {
      res += `yearTo=${this.endTIme}`
    } else if ((this.startTime == undefined || this.startTime == '任何' ? -1 : Number(this.startTime)) <
      (this.endTIme == undefined || this.endTIme == '任何' ? -1 : Number(this.endTIme))) {
      res += `yearFrom=${this.startTime}&yearTo=${this.endTIme}`
    }

    this.chooseLanguageArray.forEach((item: string, index: number) => {
      if (index != this.chooseLanguageArray.length - 1) {
        tempRes += `languages[]=${item}&`
      } else {
        tempRes += `languages[]=${item}`
      }
    })
    if (tempRes != '') {
      if (res != '') {
        res += `&${tempRes}`
      } else {
        res = tempRes
      }
    }
    tempRes = ''
    this.chooseFormatArray.forEach((item: string, index: number) => {
      if (index != this.chooseFormatArray.length - 1) {
        tempRes += `extensions[]=${item}&`
      } else {
        tempRes += `extensions[]=${item}`
      }
    })
    if (tempRes != '') {
      if (res != '') {
        res += `&${tempRes}`
      } else {
        res = tempRes
      }
    }
    tempRes = ''
    return res
  }

  @Builder
  languagePopupBuilder() {
    Column() {
      List() {
        ForEach(languageArray, (item: I_KV) => {
          ListItem() {
            Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
              Checkbox({ name: item.key.toString(), group: 'languageChoose' })
                .select(this.chooseLanguageArray.includes(item.value.toString()))
                .selectedColor($r('app.color.linder_pink'))
                .shape(CheckBoxShape.CIRCLE)
                .onChange((value: boolean) => {
                  if (value) {
                    this.chooseLanguageArray.push(item.value.toString())
                  } else {
                    this.chooseLanguageArray =
                      this.chooseLanguageArray.filter((value: string) => value != item.value.toString())
                  }
                })
              Text(item.key.toString())
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
          }.size({ width: '100%', height: '48' })
        })
      }.width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
    }.size({ height: 250, width: 200 })
  }

  @Builder
  formatPopupBuilder() {
    Column() {
      List() {
        ForEach(formatArray, (item: I_KV) => {
          ListItem() {
            Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
              Checkbox({ name: item.key.toString(), group: 'formatChoose' })
                .select(this.chooseFormatArray.includes(item.value.toString()))
                .selectedColor($r('app.color.linder_pink'))
                .shape(CheckBoxShape.CIRCLE)
                .onChange((value: boolean) => {
                  if (value) {
                    this.chooseFormatArray.push(item.value.toString())
                  } else {
                    this.chooseFormatArray =
                      this.chooseFormatArray.filter((value: string) => value != item.value.toString())
                  }
                })
              Text(item.key.toString())
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
          }.size({ width: '100%', height: '48' })
        })
      }.width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
    }.size({ height: 250, width: 200 })
  }

  @Builder
  searchOptionBuilder() {
    Scroll() {
      Column({ space: 10 }) {
        ListItemWithText({
          leftMessage: '起始年份',
          rightMessage: this.startTime ?? '任何',

        }).onClick(() => {
          this.getUIContext().showTextPickerDialog({
            range: timeArray,
            selected: this.startTImeIndex,
            defaultPickerItemHeight: 40,
            onAccept: (value: TextPickerResult) => {
              this.startTime = value.value.toString()
              this.startTImeIndex = value.index
            }
          })
        })

        ListItemWithText({
          leftMessage: '终止',
          rightMessage: this.endTIme ?? '任何',

        }).onClick(() => {
          this.getUIContext().showTextPickerDialog({
            range: timeArray,
            selected: this.endTImeIndex ?? this.startTImeIndex,
            defaultPickerItemHeight: 40,
            onAccept: (value: TextPickerResult) => {
              this.endTIme = value.value.toString()
              this.endTImeIndex = value.index
            }
          })
        })

        ListItemWithText({
          leftMessage: '语言',
          rightMessage: this.chooseLanguageArray.length == 0 ? '全部' : JSON.stringify(this.chooseLanguageArray),
        })
          .onClick(() => {
            this.showLanguagePopup = true
          })
          .bindPopup($$this.showLanguagePopup, {
            builder: this.languagePopupBuilder(),
            placement: Placement.RightBottom,
            onStateChange: (e) => {
              this.showLanguagePopup = e.isVisible
            }
          })

        ListItemWithText({
          leftMessage: '格式',
          rightMessage: this.chooseFormatArray.length == 0 ? '全部' : JSON.stringify(this.chooseFormatArray),
        })
          .onClick(() => {
            this.showFormatPopup = true
          })
          .bindPopup($$this.showFormatPopup, {
            builder: this.formatPopupBuilder(),
            placement: Placement.RightBottom,
            onStateChange: (e) => {
              this.showFormatPopup = e.isVisible
            }
          })

        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(40)
              .fontColor([$r('sys.color.font_secondary')])
          }
          .width(60)
          .height(60)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(100)
          .useEffect(true)
          .onClick(() => {
            this.startTime = undefined
            this.startTImeIndex = 0
            this.endTIme = undefined
            this.endTImeIndex = undefined
            this.chooseFormatArray = []
            this.chooseLanguageArray = []
          })


          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(40)
              .fontColor([$r('sys.color.font_secondary')])
          }
          .width(60)
          .height(60)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(100)
          .useEffect(true)
          .onClick(() => {
            const specialUrl = this.generateUrl()
            __zlibHomeData__.searchIndex = 1
            zlibClient.searchBooks(this.searchBookName, 1, true, specialUrl)
            XAnimation.runWithAnimation(() => {
              __zlibHomeData__.searchOrRecommend = zlibIndexShowMod.Search
            })
            this.showSearchOption = false
          })

        }.width('100%')
        .margin({ top: 10 })
        .justifyContent(FlexAlign.SpaceBetween)

      }.size({ width: '100%' })
      .padding({ left: 16, right: 16, })
      .margin({ bottom: 16 })
    }.size({ width: '100%', height: '100%' })
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)

  }

  @Builder
  waterFlow_recommend() {
    LazyForEach(zlibClient.recommendBooksArray, (item: I_RecommendBook, index: number) => {
      FlowItem() {
        Column({ space: 20 }) {
          Image(item.cover)
            .draggable(false)
            .size({ width: '100%' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Column({ space: 2 }) {
            Text(item.title)
              .fontSize(16)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE }).fontWeight(FontWeight.Medium)
            Text(item.author)
              .fontSize(12)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.6)
          }.alignItems(HorizontalAlign.Start)

        }.alignItems(HorizontalAlign.Start)
      }
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
      .padding(15)
      .width('100%')
      .backgroundColor(__CustomBackgroundData__.customBackground ? $r('app.color.start_window_background_blur') :
      $r('sys.color.comp_background_list_card'))
      .backdropBlur(__CustomBackgroundData__.customBackground ? 100 : undefined)
      .useEffect(true)
      .borderRadius(15)
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
        .animation({ curve: curves.springMotion(0.5, 0.7) }))
      .onClick(() => {
        this.openRecommend(item)
      })
    }, (item: string) => item)
  }

  @Builder
  list_recommend() {
    LazyForEach(zlibClient.recommendBooksArray, (item: I_RecommendBook, index: number) => {
      ListItem() {
        Row({ space: 10 }) {
          Image(item.cover)
            .draggable(false)
            .size({ height: '100%', width: '62' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Column({ space: 2 }) {
            Text(item.title)
              .fontWeight(FontWeight.Medium)
              .fontSize(20)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
            Text(item.author)
              .maxLines(1)
              .fontSize(14)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.8)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.size({ width: '100%', height: '100%' })
        .padding(15)
      }
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
      .onClick(() => {
        this.openRecommend(item)
      })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
        .animation({ curve: curves.springMotion(0.5, 0.7) }))
      .backgroundColor(__CustomBackgroundData__.customBackground ? $r('app.color.start_window_background_blur') :
      $r('sys.color.comp_background_list_card'))
      .backdropBlur(__CustomBackgroundData__.customBackground ? 100 : undefined)
      .useEffect(true)
      .borderRadius(20)
      .size({ width: '100%', height: 120 })
    })
  }

  @Builder
  waterFlow_search() {
    LazyForEach(zlibClient.searchBooksArray, (item: I_searchBook, index: number) => {
      FlowItem() {
        Column({ space: 20 }) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            Image(item.image)
              .draggable(false)
              .size({ width: '100%' })
              .shadow({
                radius: 25,
                color: Color.Gray,
                offsetX: 0,
                offsetY: 10
              })

            Text(item.extension)
              .fontSize(12)
              .padding({
                left: 7,
                right: 7,
                top: 3,
                bottom: 3
              })
              .backdropBlur(50)
              .borderRadius({ topLeft: 5 })
              .backgroundColor($r('app.color.start_window_background_blur'))
          }

          Column({ space: 2 }) {
            Text(item.title)
              .fontSize(16)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE }).fontWeight(FontWeight.Medium)
            Text(item.writer)
              .fontSize(12)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.6)
          }.alignItems(HorizontalAlign.Start)

        }.alignItems(HorizontalAlign.Start)
      }
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .padding(15)
      .backgroundColor(__CustomBackgroundData__.customBackground ? $r('app.color.start_window_background_blur') :
      $r('sys.color.comp_background_list_card'))
      .backdropBlur(__CustomBackgroundData__.customBackground ? 100 : undefined)
      .useEffect(true)
      .borderRadius(15)
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
        .animation({ curve: curves.springMotion(0.5, 0.7) }))
      .onClick(() => {
        this.openSearch(item)
      })
    }, (item: string) => item)
  }

  @Builder
  list_search() {
    LazyForEach(zlibClient.searchBooksArray, (item: I_searchBook, index: number) => {
      ListItem() {
        Row({ space: 10 }) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            Image(item.image)
              .draggable(false)
              .size({ height: '100%', width: '62' })
              .shadow({
                radius: 25,
                color: Color.Gray,
                offsetX: 0,
                offsetY: 10
              })

            Text(item.extension)
              .fontSize(10)
              .padding({
                left: 5,
                right: 5,
                top: 2,
                bottom: 2
              })
              .backdropBlur(50)
              .borderRadius({ topLeft: 5 })
              .backgroundColor($r('app.color.start_window_background_blur'))
          }


          Column({ space: 2 }) {
            Text(item.title)
              .fontWeight(FontWeight.Medium)
              .fontSize(20)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
            Text(item.writer)
              .maxLines(1)
              .fontSize(14)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.8)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.size({ width: '100%', height: '100%' })
        .padding(15)
      }
      .onClick(() => {
        this.openSearch(item)
      })
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
        .animation({ curve: curves.springMotion(0.5, 0.7) }))
      .backgroundColor(__CustomBackgroundData__.customBackground ? $r('app.color.start_window_background_blur') :
      $r('sys.color.comp_background_list_card'))
      .backdropBlur(__CustomBackgroundData__.customBackground ? 100 : undefined)
      .useEffect(true)
      .borderRadius(20)
      .size({ width: '100%', height: 120 })
    })
  }

  async openRecommend(item: I_RecommendBook) {
    __zlibHomeData__.isOpening = true
    await zlibClient.getBookInfo(item.url).then((res) => {
      if (res.name != '' && res.name != undefined) {
        res.bookID = item.id
        res.image = item.cover
        res.href = item.url
        setContinueState(true, 'book', JSON.stringify(item), '')
        __UI__.HomePageStack.removeByName('bookInfoPage')
        __UI__.HomePageStack.pushPathByName('bookInfoPage', res)
      }
      __zlibHomeData__.isOpening = false
    })
  }

  async openSearch(item: I_searchBook) {
    __zlibHomeData__.isOpening = true
    await zlibClient.getBookInfo(item.href).then((res) => {
      if (res.name != '' && res.name != undefined) {
        res.bookID = Number(item.id)
        res.image = item.image
        res.href = item.href
        setContinueState(true, 'book', '#' + JSON.stringify(item), '')
        __UI__.HomePageStack.removeByName('bookInfoPage')
        __UI__.HomePageStack.pushPathByName('bookInfoPage', res)
      }
      __zlibHomeData__.isOpening = false
    })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (__zlibHomeData__.isOpening) {
        loadingDialog()
      }
      //顶部搜索栏
      Row({ space: 10 }) {

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.circle_viewfinder'))
            .fontSize(24)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('app.color.start_window_background_blur'))
        .backdropBlur(100)
        .useEffect(true)
        .onClick(() => {
          addLog('ScanCode', `尝试扫码`)
          let options: scanBarcode.ScanOptions = {
            scanTypes: [scanCore.ScanType.ONE_D_CODE],
            enableMultiMode: true,
            enableAlbum: true
          };
          try {
            scanBarcode.startScanForResult(globlContext, options).then((result: scanBarcode.ScanResult) => {
              addLog('ScanCode', `扫码成功,书籍ISBN为${result.originalValue}`)
              const specialUrl = this.generateUrl()
              this.scrollerOffset = 0
              __zlibHomeData__.searchIndex = 1
              this.searchBookName = result.originalValue
              zlibClient.searchBooks(result.originalValue, 1, true, specialUrl)
              XAnimation.runWithAnimation(() => {
                __zlibHomeData__.searchOrRecommend = zlibIndexShowMod.Search
              })
            }).catch((error: BusinessError) => {
              addLog('ScanCode', `扫码错误,${JSON.stringify(error)}`, true)
            });
          } catch (error) {
            addLog('ScanCode', `扫码错误,${JSON.stringify(error)}`, true)
          }
        })
        .visibility(__zlibHomeData__.isInSearchMode ? Visibility.None : Visibility.Visible)

        Select([{ value: '常规搜索' }, { value: '关键词搜索' }])
          .selected($$this.searchType)//默认选中项
          .onSelect((index) => {
            this.searchType = index
          })
          .height(40)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(100)
          .useEffect(true)
          .value(['常规搜索', '关键词搜索'][this.searchType])//默认文本
          .visibility(__zlibHomeData__.isInSearchMode ? Visibility.Visible : Visibility.None)

        Search({ value: $$this.searchBookName })
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(100)
          .useEffect(true)
          .layoutWeight(1)
          .focusable(__zlibHomeData__.isInSearchMode)
          .enableKeyboardOnFocus(__zlibHomeData__.isInSearchMode)
          .onSubmit((value: string) => {
            __zlibHomeData__.isInSearchMode = false
            if (value == '' || value == undefined) {
              XAnimation.runWithAnimation(() => {
                __zlibHomeData__.searchOrRecommend = zlibIndexShowMod.Recommend
              })
            } else {
              this.scrollerOffset = 0
              __zlibHomeData__.searchIndex = 1
              this.searchBookName = value

              if (this.searchType == 0) {
                const specialUrl = this.generateUrl()
                zlibClient.searchBooks(value, 1, true, specialUrl)
              }else {
                zlibClient.searchTerms(value)
              }

              XAnimation.runWithAnimation(() => {
                __zlibHomeData__.searchOrRecommend = zlibIndexShowMod.Search
              })
              zlibClient.searchHistoryArray =
                zlibClient.searchHistoryArray.filter((item: I_SearchHistory) => item.value != value)
              zlibClient.searchHistoryArray.unshift({ value: value, time: Date.parse(new Date().toString()) })
              NeoPreferencesUtil.putPreferencesValue("selineRead", 'searchHistory',
                JSON.stringify(zlibClient.searchHistoryArray))
            }
          })
          .onChange((value: string) => {
            if (value == '' || value == undefined) {
              XAnimation.runWithAnimation(() => {
                __zlibHomeData__.searchOrRecommend = zlibIndexShowMod.Recommend
              })
            }
          })
          .onTouch(() => {
            XAnimation.runWithAnimation(() => {
              __zlibHomeData__.isInSearchMode = true
            })
          })
          .constraintSize({ maxWidth: __zlibHomeData__.isInSearchMode ? '100%' : '50%' })

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(this.listOrWaterFlow == zlibIndexShowMod.WaterFlow ? $r('sys.symbol.list_bullet') :
          $r('sys.symbol.satellite_map'))
            .fontSize(24)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('app.color.start_window_background_blur'))
        .backdropBlur(100)
        .useEffect(true)
        .onClick(() => {
          addLog('changeListOrWaterFlow', `切换列表/瀑布流`)
          XAnimation.runWithAnimation(() => {
            this.scrollerOffset = 0
            this.listOrWaterFlow = this.listOrWaterFlow == zlibIndexShowMod.WaterFlow ? zlibIndexShowMod.List :
            zlibIndexShowMod.WaterFlow
          })
        })
        .visibility(__zlibHomeData__.isInSearchMode ? Visibility.None : Visibility.Visible)

      }
      .zIndex(1)
      .padding({ left: 16, right: 16, top: __System__.topRectHeight })
      .transition(XAnimation.getAnimation('up'))
      .offset({
        y: this.searchBarOffsetY
      })
      .zIndex(114514)


      if ((__zlibHomeData__.searchOrRecommend == zlibIndexShowMod.Recommend &&
        zlibClient.recommendBooksArray.dataArray.length == 0) ||
        (__zlibHomeData__.searchOrRecommend == zlibIndexShowMod.Search &&
          zlibClient.searchBooksArray.dataArray.length == 0)) {
        Stack() {
          LoadingProgress()
            .size({ width: 150, height: 150 })
        }.size({ width: '100%', height: '100%' })
      } else {
        Stack() {
          if (this.listOrWaterFlow == zlibIndexShowMod.WaterFlow) {
            WaterFlow({ scroller: this.scrollerController }) {
              ForEach(this.waterFlowEmptyItem, (item: number) => {
                FlowItem().height(__System__.topRectHeight + 60)
              })

              if (__zlibHomeData__.searchOrRecommend == zlibIndexShowMod.Recommend) {
                this.waterFlow_recommend()
              } else {
                this.waterFlow_search()
              }

              ForEach(this.waterFlowEmptyItem, (item: number) => {
                FlowItem()
                  .height(Math.max(__System__.bottomRectHeight + (__System__.windowWidth > minWidth ? 0 : 70), 16))
              })
            }
            .onAreaChange((_, newValue) => {
              XAnimation.runWithAnimation(() => {
                this.waterFlowColumnNumber = Math.max(Math.ceil(new Number(newValue.width).valueOf() / 240), 2)
                let itemList: number[] = []
                for (let index = 0; index < this.waterFlowColumnNumber; index++) {
                  itemList.push(index)
                }
                this.waterFlowEmptyItem = itemList
              }, this.waterFlowColumnNumber > 0)
            })
            .columnsTemplate(`repeat(${this.waterFlowColumnNumber},1fr)`)
            .alignSelf(ItemAlign.Center)
            .align(Alignment.Center)
            .layoutWeight(1)
            .edgeEffect(EdgeEffect.Spring)
            .columnsGap(10)
            .rowsGap(10)
            .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
              this.scrollerOffset += scrollOffset
              this.lastOffset = scrollOffset
              this.isInScroller = true
            })
            .onScrollStop(() => {
              this.isInScroller = false
            })
            .onReachStart(() => {
              this.lastOffset = -1;
              this.scrollerOffset = 0;
            })
            .onReachEnd(async () => {
              this.isFlashing = true
              if (__zlibHomeData__.searchOrRecommend != zlibIndexShowMod.Recommend) {
                await zlibClient.searchBooks(this.searchBookName, ++__zlibHomeData__.searchIndex, false)
              } else {
                await zlibClient.getRecommendBooks(++__zlibHomeData__.recommendIndex)
              }
              this.isFlashing = false
            })
          } else {

            List({ space: 10, scroller: this.scrollerController }) {
              ListItem().height(__System__.topRectHeight + 60)
              if (__zlibHomeData__.searchOrRecommend == zlibIndexShowMod.Recommend) {
                this.list_recommend()
              } else {
                this.list_search()
              }
              ListItem().height(__System__.bottomRectHeight + (__System__.windowWidth > minWidth ? 10 : 70))
            }
            .scrollBar(BarState.Off)
            .size({ width: '100%', height: '100%' })
            .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
              this.scrollerOffset += scrollOffset
              this.lastOffset = scrollOffset
              this.isInScroller = true
            })
            .onScrollStop(() => {
              this.isInScroller = false
            })
            .onReachStart(() => {
              this.lastOffset = -1;
              this.scrollerOffset = 0;
            })
            .onReachEnd(async () => {
              this.isFlashing = true
              if (__zlibHomeData__.searchOrRecommend != zlibIndexShowMod.Recommend) {
                await zlibClient.searchBooks(this.searchBookName, ++__zlibHomeData__.searchIndex, false)
              } else {
                await zlibClient.getRecommendBooks(++__zlibHomeData__.recommendIndex)
              }
              this.isFlashing = false
            })

          }

          if (__zlibHomeData__.isInSearchMode) {
            Column()
              .size({ width: '100%', height: '100%' })
              .onClick(() => {
                XAnimation.runWithAnimation(() => {
                  __zlibHomeData__.isInSearchMode = false
                })
              })
          }

        }.padding({ left: 20, right: 20 }).blur(__zlibHomeData__.isInSearchMode ? 50 : 0)
      }


      Column({ space: 15 }) {
        //返回顶部
        if (this.scrollerOffset >= 700) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.arrow_up_to_line'))
              .fontSize(30)
              .fontColor([$r('sys.color.font_secondary')])
          }
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
            .animation({ curve: curves.springMotion(0.5, 0.7) }))
          .width(50)
          .height(50)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(100)
          .useEffect(true)
          .onClick(() => {
            this.scrollerController.scrollToIndex(0)
            this.isHaveGoToTop = true
          })
        }

        //筛选
        if (__zlibHomeData__.searchOrRecommend == zlibIndexShowMod.Search) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.square_and_pencil'))
              .fontSize(30)
              .fontColor([$r('sys.color.font_secondary')])
          }
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
            .animation({ curve: curves.springMotion(0.5, 0.7) }))
          .width(50)
          .height(50)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(100)
          .useEffect(true)
          .onClick(() => {
            this.showSearchOption = true
          })
          .visibility(__zlibHomeData__.searchOrRecommend == zlibIndexShowMod.Search ? Visibility.Visible :
          Visibility.Hidden)
          .bindSheet($$this.showSearchOption, this.searchOptionBuilder(), {
            preferType: SheetType.CENTER,
            height: SheetSize.MEDIUM,
            title: { title: '搜索设置' }
          })
        }

      }.position({ bottom: 120, right: this.SideButtonOffsetX })

      if (this.isFlashing) {
        loadingNewDialog()
      }

      if (__zlibHomeData__.isInSearchMode) {
        Scroll() {
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } }) {
            ForEach(zlibClient.searchHistoryArray, (item: I_SearchHistory) => {
              Button() {
                Row({ space: 10 }) {
                  Text(item.value.slice(0, 8) + (item.value.length > 8 ? '...' : '')).maxLines(1).fontSize(14)
                  Button() {
                    SymbolGlyph($r('sys.symbol.xmark')).fontColor([$r('sys.color.font')]).fontSize(15)
                  }.padding(5)
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    XAnimation.runWithAnimation(() => zlibClient.searchHistoryArray =
                      zlibClient.searchHistoryArray.filter((itemA: I_SearchHistory) => itemA.value != item.value))
                    NeoPreferencesUtil.putPreferencesValue("selineRead", 'searchHistory',
                      JSON.stringify(zlibClient.searchHistoryArray))
                  })
                }
              }
              .padding({
                left: 10,
                right: 10,
                top: 5,
                bottom: 5
              })
              .backgroundColor($r('app.color.start_window_background_blur'))
              .onClick(() => {
                this.scrollerOffset = 0
                __zlibHomeData__.searchIndex = 1
                this.searchBookName = item.value
                const specialUrl = this.generateUrl()
                zlibClient.searchBooks(item.value, 1, true, specialUrl)
                XAnimation.runWithAnimation(() => {
                  __zlibHomeData__.searchOrRecommend = zlibIndexShowMod.Search
                  __zlibHomeData__.isInSearchMode = false
                })
                zlibClient.searchHistoryArray =
                  zlibClient.searchHistoryArray.filter((itemA: I_SearchHistory) => itemA.value != item.value)
                zlibClient.searchHistoryArray.unshift({ value: item.value, time: Date.parse(new Date().toString()) })
                NeoPreferencesUtil.putPreferencesValue("selineRead", 'searchHistory',
                  JSON.stringify(zlibClient.searchHistoryArray))
              })
            })

            if (zlibClient.searchHistoryArray.length > 0) {
              Button() {
                SymbolGlyph($r('sys.symbol.trash')).fontColor([$r('sys.color.font')]).fontSize(15)
              }
              .padding(9)
              .backgroundColor($r('app.color.start_window_background_blur'))
              .onClick(() => {
                XAnimation.runWithAnimation(() => zlibClient.searchHistoryArray = [])
                NeoPreferencesUtil.putPreferencesValue("selineRead", 'searchHistory',
                  JSON.stringify(zlibClient.searchHistoryArray))
              })
            }
          }.padding({ bottom: 10 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .transition(XAnimation.getAnimation('bottom'))
        .margin({
          top: __System__.topRectHeight + 60,
          left: 16,
          right: 16,
          bottom: Math.max(__System__.keyboardHeight, __System__.bottomRectHeight)
        })
        .zIndex(114513)
      }
    }
    .size({ height: '100%', width: '100%' })
  }
}

@ObservedV2
class zlibHomeData {
  @Trace isInSearchMode: boolean = false
  @Trace searchOrRecommend: zlibIndexShowMod = zlibIndexShowMod.Recommend
  @Trace isOpening: boolean = false
  @Trace recommendIndex: number = 1
  @Trace searchIndex: number = 1
}

export const __zlibHomeData__ = new zlibHomeData()