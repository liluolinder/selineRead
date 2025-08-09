import { display, SymbolGlyphModifier, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { readerCore, ReadPageComponent } from '@hms.core.readerservice.readerComponent';
import { bookParser } from '@kit.ReaderKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import NeoPreferencesUtil from '../datas/classes/XPreferencesUtil';
import { UIShareData, __System__, __UI__ } from '../datas/classes/ShareDatas';
import { XAnimation } from '../datas/classes/XAnimation';
import { fileUri } from '@kit.CoreFileKit';
import { globlContext } from '../../entryability/EntryAbility';

const context = getContext()

interface Catalogue{
  title: string
  path: string
  index: number
}

@Builder
export function readerBuilder(){
  Reader()
}

@ComponentV2
struct Reader{

  @Local text: string = ''
  @Local nowPage: number = 0
  @Local nowChapter: number = 0
  totalPage: number = 0

  @Local isFullscreen: boolean = true

  @Local UI: UIShareData = __UI__

  path: string = ''

  name: string = ''

  catalogueScroller: ListScroller = new ListScroller()

  @Local title: string = '阅读器'

  bookInfo: bookParser.BookInfo|undefined = undefined

  @Local catalogue: bookParser.CatalogItem[] = []

  @Local catalogueShow: boolean = false

  private readerComponentController: readerCore.ReaderComponentController = new readerCore.ReaderComponentController();

  private bookParserHandler: bookParser.BookParserHandler | null = null;

  private readerSetting: readerCore.ReaderSetting = {
    fontName: '系统字体',
    fontPath: '',
    fontSize: 18,
    fontColor: '#000000',
    fontWeight: 400,
    lineHeight: 1.9,
    nightMode: false,
    themeColor: '#f0f0f0',
    themeBgImg: '',
    flipMode: '0',
    scaledDensity: display.getDefaultDisplaySync().scaledDensity > 0 ? display.getDefaultDisplaySync().scaledDensity :
      1,
    viewPortWidth: 1000,
    viewPortHeight: 1000,
  };

  private async startPlay() {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      // 组件控制器初始化，用于控制ReadPageComponent调用排版引擎
      let initPromise = this.readerComponentController.init(context);
      // 初始化书籍解析器
      let bookParserHandler = bookParser.getDefaultHandler(this.path);
      let result: [bookParser.BookParserHandler, void] = await Promise.all([bookParserHandler, initPromise]);
      this.bookParserHandler = result[0];
      // 设置默认页面属性，用于排版的默认样式
      this.readerComponentController.setPageConfig(this.readerSetting);
      // 注册解析能力到控制器中，用于排版引擎的调用。
      this.readerComponentController.registerBookParser(this.bookParserHandler);
      // 调用打开书籍接口，跳章至对应进度
      NeoPreferencesUtil.localPreferences(globlContext, 'reader')
      const d = NeoPreferencesUtil.getPreferencesValue('reader', this.name, []) as string[]
      this.readerComponentController.startPlay(parseInt(d[0] || '0'), d[1] || '')
      this.updateBackgroundColor()
      this.readerComponentController.on('pageShow', (callback)=>{
        this.nowChapter = callback.resourceIndex
        this.nowPage = callback.pageOffset
        NeoPreferencesUtil.putPreferencesValue('reader', this.name, [callback.resourceIndex.toString(), callback.startDomPos])
      })
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'startPlay: err: ' + JSON.stringify(err));
    }
  }

  @Monitor('UI.currentColorMode')
  updateBackgroundColor(){
    try{
      this.readerSetting.fontColor = this.UI.currentColorMode == 0? '#f0f0f0': '#202020'
      this.readerSetting.themeColor = this.UI.currentColorMode == 0? '#000000': '#f0f0f0'
      this.readerComponentController.setPageConfig(this.readerSetting);
    }catch{}

  }

  @Monitor('isFullScreen')
  updateSystemBar(){
    window.getLastWindow(context).then((windowClass) => {
      windowClass.setSpecificSystemBarEnabled('status', !this.isFullscreen)
      windowClass.setSpecificSystemBarEnabled('navigationIndicator', !this.isFullscreen)
    })
  }

  aboutToDisappear(): void {
    this.isFullscreen = false
    // 退出需要释放阅读器实例
    this.readerComponentController.releaseBook();
  }

  build() {
    NavDestination() {
      Stack(){
        ReadPageComponent({
          controller: this.readerComponentController,
          readerCallback: (err: BusinessError, data: readerCore.ReaderComponentController) => {
            this.readerComponentController = data;
          }
        })
          .onAreaChange((oldValue: Area, newValue: Area)=>{
            try{
              console.log('testTAG', new Number(newValue.width).valueOf(), new Number(newValue.height).valueOf())
              this.readerSetting.viewPortWidth = vp2px(parseFloat(newValue.width.toString()))
              this.readerSetting.viewPortHeight = vp2px(parseFloat(newValue.height.toString()))
              this.readerComponentController.setPageConfig(this.readerSetting);
            }catch{
            }
          })

        Flex({direction: FlexDirection.Column, justifyContent: FlexAlign.SpaceBetween}){
          Flex({justifyContent: FlexAlign.SpaceBetween}) {
          }
          Flex({justifyContent: FlexAlign.SpaceBetween}){
            Text(this.catalogue[this.nowChapter]?.catalogName).fontSize(12).opacity(0.6).maxLines(1).textOverflow({overflow: TextOverflow.Ellipsis})
            Text((this.nowPage + 1).toString()).fontSize(12).opacity(0.6).maxLines(1).textOverflow({overflow: TextOverflow.Ellipsis})
          }
        }.padding(15).size({width: '100%', height: '100%'}).enabled(false)
      }.size({width: '100%', height: '100%'})



      .size({width: '100%', height: '100%'})


    }.backgroundColor($r('app.color.start_window_background'))
    .title(this.title)
    .onWillAppear(()=> {
      XAnimation.runWithAnimation(() => __UI__.isInReader = true)
    })
    .onWillDisappear(()=> {
      XAnimation.runWithAnimation(() => __UI__.isInReader = false)
    })
    .padding({top: this.isFullscreen? 0: __System__.topRectHeight, bottom: this.isFullscreen? 0: __System__.bottomRectHeight})
    .onClick((event)=>{
      if(event.x > __System__.windowWidth * 0.4 && event.x < __System__.windowWidth * 0.6) XAnimation.runWithAnimation(() => this.isFullscreen = !this.isFullscreen)
    })
    .hideTitleBar(this.isFullscreen)
    .onReady((navContext)=>{
      if(navContext.pathInfo.param){
        this.path = navContext.pathInfo.param.toString()
        this.name = new fileUri.FileUri(this.path).name
        bookParser.getDefaultHandler(this.path).then((bookParserHandler)=>{
          this.bookInfo = bookParserHandler.getBookInfo();
          this.catalogue = bookParserHandler.getCatalogList()
          this.title = this.bookInfo.bookTitle
        }).catch((err:BusinessError)=>{
          console.log(`FUCK${JSON.stringify(err)}`)
          navContext.pathStack.pop(true)
        })
        this.updateSystemBar()
        this.startPlay();
      }else{
        navContext.pathStack.pop(true)
      }

    })
    .backgroundColor($r('sys.color.comp_background_gray'))
    .menus([
      {
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.list_bullet')),
        value: '',
        action:()=>{
          this.catalogueShow = true
          setTimeout(()=>{
            this.catalogueScroller.scrollToIndex(this.nowChapter)
          },10)
        }
      },
      {
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.fullscreen')),
        value: '',
        action:()=>{
          XAnimation.runWithAnimation(()=>this.isFullscreen = true)
        }
      }
    ])
    .onBackPressed(()=>{
      if(this.isFullscreen){
        XAnimation.runWithAnimation(()=>this.isFullscreen = false)
        return true
      }
      return false
    })
    .bindSheet($$this.catalogueShow, this.Catalogue(), {
      detents: [SheetSize.MEDIUM],
      backgroundColor: $r('sys.color.comp_background_gray'),
      showClose: false,
      preferType: SheetType.CENTER
    })
  }

  @Builder
  Catalogue(){
    Stack(){
      List({space: 10, scroller: this.catalogueScroller}){
        ForEach(this.catalogue, (item: bookParser.CatalogItem)=>{
          ListItem(){
            Column(){
              Text(item.catalogName || '佚名').fontSize(18).fontWeight(this.nowChapter == item.catalogId? FontWeight.Bold: FontWeight.Lighter).maxLines(1).textOverflow({overflow: TextOverflow.Ellipsis})
            }.padding({left: 15, right: 15, top: 10, bottom: 10})
            .alignItems(HorizontalAlign.Start)
            .borderRadius(15)
            .backgroundColor($r('app.color.card_list_background'))
            .width('100%')
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(()=>{
            this.catalogueShow = false
            this.nowChapter = item.catalogId
            this.readerComponentController.startPlay(item.catalogId, '')
          })
        })
      }.borderRadius(15).clip(true).size({width: '100%', height: '100%'}).scrollBar(BarState.Off)
    }.padding(20)
  }
}