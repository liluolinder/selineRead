import { BasicDataSource } from "../../../datas/classes/BasicDataSource"
import { Logger, __Logger__, __UI__ } from "../../../datas/classes/ShareDatas"
import { dateGetTime } from "../../../utils/ToolsUtil"
import { fileIo, picker } from "@kit.CoreFileKit"
import { BusinessError } from "@kit.BasicServicesKit"
import { promptAction } from "@kit.ArkUI"

export interface LogLine {
  time: number
  isError: boolean
  tag: string
  text: string
}

@Builder
export function loggerBuilder() {
  LoggerPage()
}

@ComponentV2
export struct LoggerPage {
  @Local lazy_logs: BasicDataSource<LogLine> = new BasicDataSource<LogLine>()
  private scroller: ListScroller = new ListScroller()

  @Monitor('__Logger__.logs')
  updateLogs() {
    this.lazy_logs.setData(__Logger__.logs)
  }

  aboutToAppear(): void {
    this.updateLogs()
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    })
  }

  build() {

    Column({ space: 5 }) {
      Stack({ alignContent: Alignment.Start }) {
        Row({ space: 10 }) {
          Stack().size({ width: 15, height: 15 }).borderRadius(100).backgroundColor('#fa6457')
            .onClick(() => __UI__.showLogger = false)
          Stack().size({ width: 15, height: 15 }).borderRadius(100).backgroundColor('#fbb02f')
            .onClick(() => {
              __Logger__.logs = []
              this.lazy_logs.clearData()
              promptAction.showToast({ message: '已清除所有日志', duration: 2000 })
            })
          Stack().size({ width: 15, height: 15 }).borderRadius(100).backgroundColor('#2bbd2f')
            .onClick(() => {
              let saverOption = new picker.DocumentSaveOptions()
              saverOption.newFileNames =
                ['log_' + dateGetTime(new Date().getTime(), true, true).replace(/[.: ]/g, '_') +
                  '.log']
              let saver = new picker.DocumentViewPicker(getContext())
              saver.save(saverOption, (err: BusinessError, documentSaveResult: string[]) => {
                if (!err) {
                  let file = fileIo.openSync(documentSaveResult[0], fileIo.OpenMode.READ_WRITE)
                  let text = ''
                  __Logger__.logs.forEach((log) => {
                    text += `${dateGetTime(log.time, true, false)} [${log.tag}]${log.text}` + '\n'
                  })
                  fileIo.writeSync(file.fd, text)
                  fileIo.close(file)
                }
              })
            })
        }.height(35).padding(5)
      }.width('100%')

      List({ space: 5, scroller: this.scroller }) {

        LazyForEach(this.lazy_logs, (log: LogLine) => {
          ListItem() {
            Text(`${dateGetTime(log.time, true, false)} [${log.tag}]${log.text}`)
              .fontColor(log.isError ? $r('sys.color.warning') : $r('sys.color.font'))
              .textAlign(TextAlign.Start)
              .opacity(0.9)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .copyOption(CopyOptions.LocalDevice)
          }
        })

      }
      .scrollBar(BarState.Off)
      .width('100%')
      .alignListItem(ListItemAlign.Start)
      .fadingEdge(true)
      .layoutWeight(1)
    }
    .borderRadius(25)
    .clip(true)
    .margin({
      bottom: 16,
      left: 16,
      right: 16,
      top: 18
    })
    .padding({
      top: 10,
      bottom: 10,
      left: 15,
      right: 15
    })
    .backgroundColor($r('app.color.card_list_background'))

  }
}
