import { HdsNavDestination } from "@hms.hds.hdsBaseComponent";
import { BookSourceParserArk } from "libohos_app_cangjie_entry.bookSource.so";
import { min_width } from "../../commons/commonItem";
import { __System__ } from "../../commons/shareDatas";
import { __CustomBackgroundData__ } from "../../components/CustomBackground";
import { hdsMaterial } from "@kit.UIDesignKit";

@Builder
export function SourceEditBuilder(){
  SourceEdit()
}

@ComponentV2
export struct SourceEdit{

  @Local source?:BookSourceParserArk = undefined

  cardBg(): ResourceColor {
    return __CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
      $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card')
  }

  /** 信息行：左侧标签 + 右侧内容 */
  @Builder
  infoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(14)
        .opacity(0.6)
      Text(value == '' || value == undefined ? '未知' : value)
        .fontSize(14)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  /** 单行可编辑输入框：标签 + TextInput */
  @Builder
  ruleInput(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      TextInput({ text: value, placeholder: '请输入' })
        .fontSize(14)
        .height(40)
        .borderRadius(8)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  /** 多行可编辑输入框：标签 + TextArea */
  @Builder
  ruleArea(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      TextArea({ text: value, placeholder: '请输入' })
        .fontSize(14)
        .height(100)
        .borderRadius(8)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    HdsNavDestination(){
      List({ space: 10 }) {
        // 书源名称卡片
        ListItem() {
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              Text(this.source?.bookSource.bookSourceName ?? '未知书源')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              Text(this.source?.bookSource.enabled == true ? '已启用' : '已停用')
                .fontSize(12)
                .fontColor(this.source?.bookSource.enabled == true ? Color.Green : Color.Gray)
            }
            .width('100%')
            Text(this.source?.bookSource.bookSourceGroup == '' || this.source?.bookSource.bookSourceGroup == undefined ?
              '未分组' : this.source?.bookSource.bookSourceGroup)
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
        }
        .backgroundColor(this.cardBg())
        .borderRadius(20)

        // 基本信息卡片
        ListItem() {
          Column({ space: 12 }) {
            this.infoRow('书源地址', this.source?.bookSource.bookSourceUrl ?? '')
            this.infoRow('书源类型', this.source?.bookSource.bookSourceType != undefined ?
              `${this.source?.bookSource.bookSourceType}` : '')
            this.infoRow('支持分页', this.source?.supportsPage == true ? '是' : '否')
            this.infoRow('请求头', this.source?.bookSource.header ?? '')
            this.infoRow('备注', this.source?.bookSource.bookSourceComment ?? '')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
        }
        .backgroundColor(this.cardBg())
        .borderRadius(20)

        // 搜索规则卡片
        ListItem() {
          Column({ space: 12 }) {
            Text('搜索规则')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            this.ruleInput('搜索地址', this.source?.bookSource.ruleSearch?.searchUrl ?? '')
            this.ruleInput('请求方式', this.source?.bookSource.ruleSearch?.method ?? '')
            this.ruleInput('POST 请求体', this.source?.bookSource.ruleSearch?.postBody ?? '')
            this.ruleInput('书名', this.source?.bookSource.ruleSearch?.name ?? '')
            this.ruleInput('作者', this.source?.bookSource.ruleSearch?.author ?? '')
            this.ruleInput('书籍地址', this.source?.bookSource.ruleSearch?.bookUrl ?? '')
            this.ruleInput('书籍地址模板', this.source?.bookSource.ruleSearch?.bookUrlTemplate ?? '')
            this.ruleInput('封面地址', this.source?.bookSource.ruleSearch?.coverUrl ?? '')
            this.ruleInput('简介', this.source?.bookSource.ruleSearch?.intro ?? '')
            this.ruleInput('分类', this.source?.bookSource.ruleSearch?.kind ?? '')
            this.ruleInput('字数', this.source?.bookSource.ruleSearch?.wordCount ?? '')
            this.ruleInput('最新章节', this.source?.bookSource.ruleSearch?.latestChapter ?? '')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
        }
        .backgroundColor(this.cardBg())
        .borderRadius(20)

        // 书籍信息规则卡片
        ListItem() {
          Column({ space: 12 }) {
            Text('书籍信息规则')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            this.ruleInput('地址', this.source?.bookSource.ruleBookInfo?.url ?? '')
            this.ruleInput('书名', this.source?.bookSource.ruleBookInfo?.name ?? '')
            this.ruleInput('作者', this.source?.bookSource.ruleBookInfo?.author ?? '')
            this.ruleInput('封面地址', this.source?.bookSource.ruleBookInfo?.coverUrl ?? '')
            this.ruleInput('简介', this.source?.bookSource.ruleBookInfo?.intro ?? '')
            this.ruleInput('分类', this.source?.bookSource.ruleBookInfo?.kind ?? '')
            this.ruleInput('字数', this.source?.bookSource.ruleBookInfo?.wordCount ?? '')
            this.ruleInput('最新章节', this.source?.bookSource.ruleBookInfo?.latestChapter ?? '')
            this.ruleInput('状态', this.source?.bookSource.ruleBookInfo?.status ?? '')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
        }
        .backgroundColor(this.cardBg())
        .borderRadius(20)

        // 目录规则卡片
        ListItem() {
          Column({ space: 12 }) {
            Text('目录规则')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            this.ruleInput('地址', this.source?.bookSource.ruleToc?.url ?? '')
            this.ruleInput('章节名', this.source?.bookSource.ruleToc?.chapterName ?? '')
            this.ruleInput('章节地址', this.source?.bookSource.ruleToc?.chapterUrl ?? '')
            this.ruleInput('下一页目录地址', this.source?.bookSource.ruleToc?.nextTocUrl ?? '')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
        }
        .backgroundColor(this.cardBg())
        .borderRadius(20)

        // 正文规则卡片
        ListItem() {
          Column({ space: 12 }) {
            Text('正文规则')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            this.ruleInput('地址', this.source?.bookSource.ruleContent?.url ?? '')
            this.ruleInput('正文内容', this.source?.bookSource.ruleContent?.content ?? '')
            this.ruleInput('下一页地址', this.source?.bookSource.ruleContent?.nextUrl ?? '')
            this.ruleArea('过滤规则(逗号分隔)', (this.source?.bookSource.ruleContent?.filters ?? []).join(','))
            if (this.source?.bookSource.ruleContent?.token) {
              Text('Token 配置')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .margin({ top: 4 })
              this.ruleInput('算法', this.source?.bookSource.ruleContent.token.algo ?? '')
              this.ruleInput('Key', this.source?.bookSource.ruleContent.token.key ?? '')
              this.ruleInput('IV', this.source?.bookSource.ruleContent.token.iv ?? '')
              this.ruleInput('输入源', this.source?.bookSource.ruleContent.token.input ?? '')
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
        }
        .backgroundColor(this.cardBg())
        .borderRadius(20)
      }
      .padding({left:16, right:16})
      .width('100%')
      .height('100%')
      .contentEndOffset(Math.max(16, __System__.bottomRectHeight))
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .size({ width: '100%', height: '100%' })
    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
      Color.Transparent : $r('sys.color.comp_background_gray'))
    .titleBar({
      enableComponentSafeArea: true,
      content: {
        title: {
          mainTitle: '书源详情'
        }
      },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        },
        scrollEffectOpts: {
          enableScrollEffect: false,
        },
      }
    })
    .onReady((ctx)=>{
      this.source = ctx.pathInfo.param as BookSourceParserArk
    })
  }
}
