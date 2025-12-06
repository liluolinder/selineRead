import { XAnimation } from "commonpackage"
import { ListItemWithArrow, ListItemWithText } from "templatecomponent"
import { __System__ } from "../../commons/shareDatas"
import { I_UpdateInfo } from "../../models/interfaces/I_UpdateInfo"

@Builder
export function VersionInfoBuilder() {
  VersionInfo()
}

@ComponentV2
export struct VersionInfo {
  @Local historyArray: I_UpdateInfo[] = [
    {
      version: '1.1.4.5',
      date: '2025/12/6',
      addNewFunArray: ['书架书籍删除(长按/右键菜单)','下载管理删除下载任务(左滑)','允许设置下载时，文件冲突处理办法','允许设置是否下载完成后打开华为分享'],
      optimizeArray:['优化部分界面动画','优化部分界面展示','启动后进行个人信息获取']
    },
    {
      version: '1.1.3.0',
      date: '2025/12/4',
      addNewFunArray: ['书架', '下载任务持久保存', '书架与下载任务数据绑定', '每次冷启动删除下载文件夹缓存文件', '书架右键/长按菜单', '分享书架书籍', '联网搜索书架书籍','联网查看书架书籍详细信息','导出书架书籍至三方阅读器：格物阅读/华为阅读'],
      optimizeArray:['优化部分界面动画','优化部分界面展示']
    },
    {
      version: '1.1.2.0',
      date: '2025/12/2',
      addNewFunArray: ['书架(未完成)', 'zlib服务地址管理', '下载任务查看', '侧边栏中新增关于我们',
        '展示开源项目引用(关于我们)', '提供跳转老版本链接(关于我们)'],
    },
    {
      version: '1.0.0.0',
      date: '2025/11/20',
      description: '本次版本更新为版本重构更新,此前版本更新内容均失效，后续以此版本为基线版本',
      addNewFunArray: ['首页推荐(暂无个性化)', '书籍下载功能', '搜索功能', '多账号管理(当前只可以添加，切换)', '新UI'],
      optimizeArray: ['后台下载无法正常保存', '获取书籍失败时候无明显提醒']
    },
    {
      version: '1.0.0',
      date: '2025/10/4',
      addNewFunArray: ['书单收藏', '书单筛选', '书单搜索'],
      optimizeArray: ['优化隐藏搜索框逻辑'],
      fixBugsArray: ['书库搜索框点击X未清空输入框']
    },
    {
      version: '0.8.0',
      date: '2025/9/26',
      addNewFunArray: ['新增分享书籍', '新增分享书单', '新增搜索显示年份', '书库列表显示模式持久化',
        '新增Meow频道订阅'],
      fixBugsArray: ['修复登陆后卡获取个人信息'],
      optimizeArray: ['优化导入', '修复封面异常显示']
    },
    {
      version: '0.7.0',
      date: '2025/9/14',
      addNewFunArray: ['新增搜索模式切换', '新增关键词搜索', '新增书籍详细页面书籍推荐', '新增书籍详细页面关键词',
        '新增首页个性化推荐', '返回Button(仅PC/自由多窗)', '新增订阅新url推送(目前为静默通知)'],
      optimizeArray: ['优化首页搜索栏UI', '优化搜索历史', '优化状态栏图标', '优化动画', '优化手机横屏布局',
        '优化无封面书籍展示效果', '优化逻辑'],
      fixBugsArray: ['书单异常显示', '解决版本号过低bug', '修复未打开局域网书库就进行获取',
        '修复打开局域网书库按钮，不获取书籍bug']
    },
    {
      version: '0.6.0',
      date: '2025/9/7',
      addNewFunArray: ['内置PDF阅读器', '查看书籍评论', '在线预览书籍', '搜索历史记录', '导出至华为阅读', '自定义导出',
        '键盘高度监听'],
      optimizeArray: ['优化滚动效果', '禁用Tab栏滚动', '优化双栏显示效果'],
      fixBugsArray: ['PC系统单击标题栏全屏', '解决版本号过低bug']
    },
    {
      version: '0.5.0',
      date: '2025/9/6',
      addNewFunArray: ['一键回到列表顶部', '搜索筛选', '滚动时自动隐藏侧边按钮和搜索栏'],
      fixBugsArray: ['无法获取下载链接']
    },
    {
      version: '0.4.0',
      date: '2025/9/5',
      addNewFunArray: ['新增保存封面按钮', '新增鼠标控制封面', '新增自定义背景'],
      optimizeArray: ['优化动画', '优化卡片效果'],
      fixBugsArray: ['修复P80无法正常使用问题']
    },
    {
      version: '0.3.0',
      date: '2025/9/1',
      addNewFunArray: ['新增查看大图(书籍详细页点击)', '扫描条形码并自动搜索ISBN', '运行日志', '新增接续'],
      optimizeArray: ['优化tab出现动画', '优化动画曲线', '优化层级'],
    },
    {
      version: '0.2.0',
      date: '2025/8/26',
      addNewFunArray: ['新增自定义API', '新增本地书导入', '新增API设置', '新增下载完自动分享设置', '新增书架拖动分享',
        '书架长按书籍直接导入格物阅读,搜索书籍展示主文件格式'],
      optimizeArray: ['优化动画', '更换icon(感谢群友:楠柒Zayn)', '优化部分展示效果', '优化书架展示',
        '优化书架书籍是否存在显示', '登录确定按钮位置移动', '导出至格物阅读新增校验文件是否定存在'],
      fixBugsArray: ['修复重复加载', '内置阅读器首次打开异常', '修复部分右侧箭头无法使用', '后台下载异常问题',
        '首次打开APP个人信息不加载']
    },
    {
      version: '0.1.0',
      date: '2025/8/16',
      addNewFunArray: ['新增书单', '新增引导注册页'],
      optimizeArray: ['优化Tab动画']
    },
    {
      version: '0.0.4', date: '2025/8/6', optimizeArray: ['UI优化', '新增动画']
    },
    {
      version: '0.0.3',
      date: '2025/8/5',
      addNewFunArray: ['版本信息页面', '鸣谢页面', '打开仓库按钮', '打开issues按钮']
    },
    {
      version: '0.0.2',
      date: '2025/8/4',
      fixBugsArray: ["重复入栈", '历史记录排序问题', '深色模式bug', '书籍图片异常比例', 'tabs伪卡顿', 'loding图标位置']
    },
    {
      version: '0.0.1',
      date: '2025/7/28',
      addNewFunArray: ["zlib推荐页面获取", 'zlib下载', '个人信息界面', '下载通知', '下载历史']
    },
  ]
  @Local currentIndex: number = -1
  listScroller: Scroller = new Scroller()

  build() {
    NavDestination() {
      Column() {
        List({ scroller: this.listScroller, space: 10 }) {

          ForEach(this.historyArray, (item: I_UpdateInfo, index: number) => {

            ListItemGroup() {
              ListItemWithArrow({
                message: item.version,
                subMessage: item.date,
                arrowDir: index == this.currentIndex ? 'up' : 'down',
                needButtonEffect: false
              })
                .onClick(() => {
                  if (this.currentIndex == index) {
                    XAnimation.runWithAnimation(() => {
                      this.currentIndex = -1
                    })
                  } else {
                    XAnimation.runWithAnimation(() => {
                      this.currentIndex = index
                    })
                  }
                })


              if (index == this.currentIndex) {
                ListItem() {
                  Column({ space: 5 }) {

                    if (item.description) {
                      Text(item.description)
                        .width('100%')
                        .fontColor($r('[color].color.linder_blue'))
                    }

                    if (item.addNewFunArray != undefined) {
                      Text("[新增功能]").width('100%').fontWeight(FontWeight.Bold)
                      ForEach(item.addNewFunArray, (newFun: string, indexA: number) => {
                        Text(`${indexA + 1}. ${newFun}`).width('100%').fontSize(16)

                      })
                    }

                    if (item.fixBugsArray != undefined) {
                      Text("[BUG修复]").width('100%').fontWeight(FontWeight.Bold)
                      ForEach(item.fixBugsArray, (fixBug: string, indexA: number) => {
                        Text(`${indexA + 1}. ${fixBug}`).width('100%').fontSize(16)
                      })
                    }

                    if (item.optimizeArray != undefined) {
                      Text("[优化更新]").width('100%').fontWeight(FontWeight.Bold)
                      ForEach(item.optimizeArray, (optimize: string, indexA: number) => {
                        Text(`${indexA + 1}. ${optimize}`).width('100%').fontSize(16)
                      })
                    }
                  }
                }.width('100%').padding({ left: 15, right: 15, bottom: 15 }).opacity(0.9)
              }

            }
            .transition(XAnimation.getAnimation('bottom', (index + 1) * 50))
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .borderRadius(20)
            .onClick(() => {
              if (this.currentIndex == index) {
                XAnimation.runWithAnimation(() => {
                  this.currentIndex = -1
                })
              } else {
                XAnimation.runWithAnimation(() => {
                  this.currentIndex = index
                })
              }
            })
          })

        }
        .scrollSnapAlign(ScrollSnapAlign.START)
        .contentEndOffset(16)
        .scrollBar(BarState.Off)
        .chainAnimation(true)
        .borderRadius({ topLeft: 20, topRight: 20 })
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
    }.size({ width: '100%', height: '100%' })
    .backgroundColor($r('sys.color.background_tertiary'))
    .title($r('app.string.Title_VersionInfo'))
  }
}
